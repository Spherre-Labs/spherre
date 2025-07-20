#[starknet::contract]
pub mod Spherre {
    use core::hash::{HashStateExTrait, HashStateTrait};
    use core::num::traits::Zero;
    use core::poseidon::PoseidonTrait;
    use core::serde::Serde;
    use openzeppelin::access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::security::pausable::PausableComponent;
    use openzeppelin::security::reentrancyguard::ReentrancyGuardComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use spherre::errors::Errors;
    use spherre::interfaces::ispherre::ISpherre;
    use spherre::types::{FeesType, SpherreAdminRoles};
    use spherre::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec,
    };
    use starknet::syscalls::deploy_syscall;
    use starknet::{
        ClassHash, ContractAddress, get_block_number, get_block_timestamp, get_caller_address,
        get_contract_address,
    };

    // Interface IDs

    // Events for fee management
    #[derive(Drop, starknet::Event)]
    pub struct FeeUpdated {
        pub fee_type: FeesType,
        pub amount: u256,
        pub enabled: bool,
        pub caller: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FeeTokenUpdated {
        pub old_token: ContractAddress,
        pub new_token: ContractAddress,
        pub caller: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FeeCollected {
        pub fee_type: FeesType,
        pub fee_token: ContractAddress,
        pub account: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AccountWhitelisted {
        pub account: ContractAddress,
        pub timestamp: u64,
        pub admin: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct UserWhitelisted {
        pub user: ContractAddress,
        pub timestamp: u64,
        pub admin: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AccountRemovedFromWhitelist {
        pub account: ContractAddress,
        pub timestamp: u64,
        pub admin: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct UserRemovedFromWhitelist {
        pub user: ContractAddress,
        pub timestamp: u64,
        pub admin: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct DeploymentFeeCollected {
        pub sender: ContractAddress,
        pub amount: u256,
        pub spherre_share: u256,
        pub account_share: u256,
        pub fee_token: ContractAddress,
        pub timestamp: u64,
    }

    #[storage]
    struct Storage {
        owner: ContractAddress,
        // Class hash of the multisig account contract to be deployed
        account_class_hash: ClassHash,
        // Array to store all deployed account contract addresses
        accounts: Vec<ContractAddress>,
        // Mapping to quickly check if an address is a deployed account
        is_account: Map<ContractAddress, bool>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
        #[substorage(v0)]
        access_control: AccessControlComponent::Storage,
        #[substorage(v0)]
        pub src5: SRC5Component::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        // Fee management
        fee_amounts: Map<FeesType, u256>,
        fee_token_address: ContractAddress,
        fee_enabled: Map<FeesType, bool>,
        // Deployment fee percentage (in basis points, e.g., 1000 = 10%)
        deployment_fee_percentage: u64, // 0-10000 (10000 = 100%)
        // Fee collection statistics
        // (fees_type, fees_token, account) -> amount collected
        fee_collection_amounts: Map<(FeesType, ContractAddress, ContractAddress), u256>,
        // Whitelist management
        whitelisted_accounts: Map<ContractAddress, bool>,
        whitelisted_users: Map<ContractAddress, bool>,
        account_whitelist_time: Map<ContractAddress, u64>,
        user_whitelist_time: Map<ContractAddress, u64>,
        whitelisted_accounts_count: u256,
        whitelisted_users_count: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AccountDeployed: AccountDeployed,
        AccountClassHashUpdated: AccountClassHashUpdated,
        FeeUpdated: FeeUpdated,
        FeeTokenUpdated: FeeTokenUpdated,
        FeeCollected: FeeCollected,
        AccountWhitelisted: AccountWhitelisted,
        UserWhitelisted: UserWhitelisted,
        AccountRemovedFromWhitelist: AccountRemovedFromWhitelist,
        UserRemovedFromWhitelist: UserRemovedFromWhitelist,
        DeploymentFeeCollected: DeploymentFeeCollected,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AccountClassHashUpdated {
        pub old_class_hash: ClassHash,
        pub new_class_hash: ClassHash,
        pub caller: ContractAddress,
    }

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(
        path: ReentrancyGuardComponent, storage: reentrancy_guard, event: ReentrancyGuardEvent,
    );
    component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // Implement Ownable mixin
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // Implement Pausable mixin
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;

    // Implement ReentrancyGuard mixin (only has InternalImpl)
    impl ReentrancyGuardInternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;

    // Implement AccessControl mixin
    impl AccessControlMixinImpl = AccessControlComponent::AccessControlMixinImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    // Implement SRC5 mixin
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

    // Upgradeable component implementation
    pub impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;


    #[derive(Drop, starknet::Event)]
    struct AccountDeployed {
        account_address: ContractAddress,
        owner: ContractAddress,
        name: ByteArray,
        description: ByteArray,
        members: Array<ContractAddress>,
        threshold: u64,
        deployer: ContractAddress,
        date_deployed: u64,
    }

    #[constructor]
    pub fn constructor(ref self: ContractState, owner: ContractAddress) {
        // Initialize Ownable
        self.ownable.initializer(owner);

        // Initialize AccessControl and grant DEFAULT_ADMIN_ROLE to owner
        self.access_control.initializer();
        self.access_control._grant_role(DEFAULT_ADMIN_ROLE, owner);
        self.access_control._grant_role(SpherreAdminRoles::SUPERADMIN, owner);
    }

    // Implement the ISpherre interface
    #[abi(embed_v0)]
    pub impl SpherreImpl of ISpherre<ContractState> {
        fn grant_superadmin_role(ref self: ContractState, account: ContractAddress) {
            self.ownable.assert_only_owner();
            self.access_control._grant_role(SpherreAdminRoles::SUPERADMIN, account);
        }
        fn grant_staff_role(ref self: ContractState, account: ContractAddress) {
            self.assert_only_superadmin();
            self.access_control._grant_role(SpherreAdminRoles::STAFF, account);
        }
        fn revoke_superadmin_role(ref self: ContractState, account: ContractAddress) {
            self.ownable.assert_only_owner();
            self.access_control._revoke_role(SpherreAdminRoles::SUPERADMIN, account);
        }
        fn revoke_staff_role(ref self: ContractState, account: ContractAddress) {
            self.assert_only_superadmin();
            self.access_control._revoke_role(SpherreAdminRoles::STAFF, account);
        }
        fn has_staff_role(self: @ContractState, account: ContractAddress) -> bool {
            self.access_control.has_role(SpherreAdminRoles::STAFF, account)
        }
        fn has_superadmin_role(self: @ContractState, account: ContractAddress) -> bool {
            self.access_control.has_role(SpherreAdminRoles::SUPERADMIN, account)
        }
        fn pause(ref self: ContractState) {
            self.assert_only_superadmin();
            self.pausable.pause();
        }

        fn unpause(ref self: ContractState) {
            self.assert_only_superadmin();
            self.pausable.unpause();
        }

        fn deploy_account(
            ref self: ContractState,
            owner: ContractAddress,
            name: ByteArray,
            description: ByteArray,
            members: Array<ContractAddress>,
            threshold: u64,
        ) -> ContractAddress {
            self.pausable.assert_not_paused();

            let deployer = get_caller_address();
            let deployer_contract = get_contract_address();

            let fee_type = FeesType::DEPLOYMENT_FEE;
            let fee_token = self.get_fee_token();

            let class_hash = self.account_class_hash.read();
            // Check that the Classhash is set
            assert(!class_hash.is_zero(), Errors::ERR_ACCOUNT_CLASSHASH_UNKNOWN);
            // Generate unique salt from blocktimestamp and block number
            let salt = PoseidonTrait::new()
                .update_with(get_block_timestamp())
                .update_with(get_block_number())
                .finalize();

            // Serialize the argument for the deployment
            let mut calldata: Array<felt252> = array![];
            deployer_contract.serialize(ref calldata);
            owner.serialize(ref calldata);
            name.serialize(ref calldata);
            description.serialize(ref calldata);
            members.serialize(ref calldata);
            threshold.serialize(ref calldata);

            let (account_address, _) = deploy_syscall(class_hash, salt, calldata.span(), true)
                .unwrap();
            // Add account to deployed addresses list
            self.accounts.append().write(account_address);
            self.is_account.entry(account_address).write(true);

            // Collect deployment fees if enabled
            let fee_enabled = self.is_fee_enabled(fee_type);
            if fee_enabled {
                let erc20 = IERC20Dispatcher { contract_address: fee_token };
                let fee = self.get_fee(fee_type, deployer);
                assert(fee_token.is_non_zero(), Errors::ERR_TOKEN_NOT_SET);
                // Check deployer's balance and allowance
                assert(fee.is_non_zero(), Errors::ERR_FEE_NOT_SET);
                let balance = erc20.balance_of(deployer);
                assert(balance >= fee, Errors::ERR_INSUFFICIENT_FEE);
                let allowance = erc20.allowance(deployer, deployer_contract);
                assert(allowance >= fee, Errors::ERR_INSUFFICIENT_ALLOWANCE);
                let account_share = self.collect_deployment_fees(deployer);
                
                // Transfer a percentage to newly deployed account
                erc20.transfer(account_address, account_share);
            }

            // Emit AccountDeployed event
            let event = AccountDeployed {
                account_address,
                owner,
                name,
                description,
                members,
                threshold,
                deployer: deployer_contract,
                date_deployed: get_block_timestamp(),
            };
            self.emit(event);
            account_address
        }
        fn is_deployed_account(self: @ContractState, account: ContractAddress) -> bool {
            self.is_account.entry(account).read()
        }

        fn update_account_class_hash(ref self: ContractState, new_class_hash: ClassHash) {
            // Ensure only superadmin can call this function
            self.assert_only_superadmin();

            // Validate that the new class hash is not zero
            assert(!new_class_hash.is_zero(), Errors::ERR_INVALID_CLASS_HASH);

            // Get current class hash for event emission
            let old_class_hash = self.account_class_hash.read();

            // Prevent updating to the same class hash
            assert(new_class_hash != old_class_hash, Errors::ERR_SAME_CLASS_HASH);

            // Update the storage
            self.account_class_hash.write(new_class_hash);

            // Emit event
            self
                .emit(
                    AccountClassHashUpdated {
                        old_class_hash, new_class_hash, caller: get_caller_address(),
                    },
                );
        }

        fn get_account_class_hash(self: @ContractState) -> ClassHash {
            self.account_class_hash.read()
        }

        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // This function can only be called by super_admin
            self.assert_only_superadmin();

            // Replace the class hash, hence upgrading the contract
            self.upgradeable.upgrade(new_class_hash);
        }

        /// Update the fee amount for a given fee type. Only STAFF_ROLE can call.
        fn update_fee(ref self: ContractState, fee_type: FeesType, amount: u256) {
            self.assert_only_staff();
            // Update fee amount
            self.fee_amounts.entry(fee_type).write(amount);
            // Enable fee if not already enabled
            if !self.fee_enabled.entry(fee_type).read() {
                self.fee_enabled.entry(fee_type).write(true);
            }
            // Emit event
            self.emit(FeeUpdated { fee_type, amount, enabled: true, caller: get_caller_address() });
        }
        /// Update the fee token address. Only SUPERADMIN_ROLE can call.
        fn update_fee_token(ref self: ContractState, token_address: ContractAddress) {
            self.assert_only_superadmin();
            // Validate token address is not zero
            assert(!token_address.is_zero(), Errors::ERR_NON_ZERO_ADDRESS_TOKEN);
            let old_token = self.fee_token_address.read();
            self.fee_token_address.write(token_address);
            // Emit event
            self
                .emit(
                    FeeTokenUpdated {
                        old_token, new_token: token_address, caller: get_caller_address(),
                    },
                );
        }
        /// Get the fee amount for a given fee type. Returns 0 if not set.
        fn get_fee(self: @ContractState, fee_type: FeesType, account: ContractAddress) -> u256 {
            assert(account.is_non_zero(), Errors::ERR_NON_ZERO_ACCOUNT);
            // TODO: create special logic for treating fees of whitelisted accounts.
            if self.is_fee_enabled(fee_type) {
                self.fee_amounts.entry(fee_type).read()
            } else {
                0
            }
        }
        /// Get the current fee token address.
        fn get_fee_token(self: @ContractState) -> ContractAddress {
            self.fee_token_address.read()
        }
        /// Check if a fee type is enabled.
        fn is_fee_enabled(self: @ContractState, fee_type: FeesType) -> bool {
            self.fee_enabled.entry(fee_type).read()
        }
        /// Update fee collection statistics
        fn update_fee_collection_statistics(
            ref self: ContractState, fee_type: FeesType, amount: u256,
        ) {
            let account = get_caller_address();
            self.assert_only_deployed_account();
            // Get the current fee token
            let fee_token = self.get_fee_token();
            // Get the statistics map object
            let fee_statistics = self.fee_collection_amounts.entry((fee_type, fee_token, account));
            let collected_amount = fee_statistics.read();
            // Update collected amount
            fee_statistics.write(collected_amount + amount);
            // Emit fee collected statistics event
            self.emit(FeeCollected { fee_type, fee_token, amount, account });
        }
        fn get_fees_collected(
            self: @ContractState, fee_type: FeesType, account: ContractAddress,
        ) -> u256 {
            self.assert_only_deployed_account();
            // Get the current fee token
            let fee_token = self.get_fee_token();
            // Get the statistics map object and read its value
            self.fee_collection_amounts.entry((fee_type, fee_token, account)).read()
        }

        /// Whitelists an account. Only STAFF_ROLE can call.
        fn whitelist_account(ref self: ContractState, account: ContractAddress) {
            // Validate that the account parameter is not zero
            assert(account.is_non_zero(), Errors::ERR_NON_ZERO_ACCOUNT);
            // Validate that the caller has the staff role
            self.assert_only_staff();
            // Validate that the account parameter is a deployed account
            assert(self.is_deployed_account(account), Errors::ERR_ACCOUNT_NOT_DEPLOYED);
            // Check if the account is already whitelisted
            let is_whitelisted = self.whitelisted_accounts.entry(account).read();
            assert(!is_whitelisted, Errors::ERR_ACCOUNT_ALREADY_WHITELISTED);

            // Whitelist the account
            self.whitelisted_accounts.entry(account).write(true);
            self.whitelisted_accounts_count.write(self.whitelisted_accounts_count.read() + 1);

            // Set the whitelist timestamp
            let timestamp = get_block_timestamp();
            self.account_whitelist_time.entry(account).write(timestamp);

            // Emit AccountWhitelisted event
            let event = AccountWhitelisted { account, timestamp, admin: get_caller_address(), };
            self.emit(event);
        }

        /// Whitelists a user. Only STAFF_ROLE can call.
        fn whitelist_user(ref self: ContractState, user: ContractAddress) {
            // Validate that the user parameter is not zero
            assert(user.is_non_zero(), Errors::ERR_USER_ADDRESS_IS_ZERO);
            // Validate that the caller has the staff role
            self.assert_only_staff();
            // Check if the user is already whitelisted
            let is_whitelisted = self.whitelisted_users.entry(user).read();
            assert(!is_whitelisted, Errors::ERR_USER_ALREADY_WHITELISTED);

            // Whitelist the user
            self.whitelisted_users.entry(user).write(true);
            self.whitelisted_users_count.write(self.whitelisted_users_count.read() + 1);

            // Set the whitelist timestamp
            let timestamp = get_block_timestamp();
            self.user_whitelist_time.entry(user).write(timestamp);

            let event = UserWhitelisted { user, timestamp, admin: get_caller_address(), };
            self.emit(event);
        }

        /// Remove an account from whitelist. Only STAFF_ROLE can call.
        fn remove_account_from_whitelist(ref self: ContractState, account: ContractAddress) {
            self.assert_only_staff();
            // Validate that the account parameter is not zero
            assert(account.is_non_zero(), Errors::ERR_NON_ZERO_ACCOUNT);
            // Check if the account is whitelisted
            let is_whitelisted = self.whitelisted_accounts.entry(account).read();
            assert(is_whitelisted, Errors::ERR_ACCOUNT_NOT_WHITELISTED);
            // Remove the account from the whitelist
            self.whitelisted_accounts.entry(account).write(false);
            // Decrement whitelisted accounts count
            self.whitelisted_accounts_count.write(self.whitelisted_accounts_count.read() - 1);

            // Emit AccountRemovedFromWhitelist event
            let timestamp = get_block_timestamp();
            let event = AccountRemovedFromWhitelist {
                account, timestamp, admin: get_caller_address(),
            };
            self.emit(event);
        }

        /// Remove a user from whitelist. Only STAFF_ROLE can call.
        fn remove_user_from_whitelist(ref self: ContractState, user: ContractAddress) {
            self.assert_only_staff();
            // Validate that the user parameter is not zero
            assert(user.is_non_zero(), Errors::ERR_USER_ADDRESS_IS_ZERO);
            // Check if the user is whitelisted
            let is_whitelisted = self.whitelisted_users.entry(user).read();
            assert(is_whitelisted, Errors::ERR_USER_NOT_WHITELISTED);
            // Remove the user from the whitelist
            self.whitelisted_users.entry(user).write(false);
            // Decrement whitelisted users count
            self.whitelisted_users_count.write(self.whitelisted_users_count.read() - 1);

            // Emit UserRemovedFromWhitelist event
            let timestamp = get_block_timestamp();
            let event = UserRemovedFromWhitelist { user, timestamp, admin: get_caller_address(), };
            self.emit(event);
        }

        /// Check if an account is whitelisted.
        fn is_whitelisted_account(self: @ContractState, account: ContractAddress) -> bool {
            if account.is_zero() {
                return false;
            }
            self.whitelisted_accounts.entry(account).read()
        }

        /// Check if a user is whitelisted.
        fn is_whitelisted_user(self: @ContractState, user: ContractAddress) -> bool {
            if user.is_zero() {
                return false;
            }
            self.whitelisted_users.entry(user).read()
        }

        /// Get the total number of whitelisted accounts.
        fn get_whitelisted_accounts_count(self: @ContractState) -> u256 {
            self.whitelisted_accounts_count.read()
        }

        /// Get the total number of whitelisted users.
        fn get_whitelisted_users_count(self: @ContractState) -> u256 {
            self.whitelisted_users_count.read()
        }

        /// Get the timestamp when an address was whitelisted.
        /// Returns 0 if the address is not whitelisted or is zero.
        fn get_whitelist_time(
            self: @ContractState, address: ContractAddress, is_account: bool
        ) -> u64 {
            if is_account {
                self.account_whitelist_time.entry(address).read()
            } else {
                self.user_whitelist_time.entry(address).read()
            }
        }


    }

    #[generate_trait]
    pub impl InternalImpl of InternalTrait {
        /// Asserts that the caller has the staff role.
        ///
        /// # Panics
        /// This function raises an error if the caller does not have the staff role.
        fn assert_only_staff(self: @ContractState) {
            let caller = get_caller_address();
            assert(
                self.has_staff_role(caller) || self.has_superadmin_role(caller),
                Errors::ERR_NOT_A_STAFF,
            )
        }
        /// Asserts that the caller has the superadmin role.
        ///
        /// # Panics
        /// This function raises an error if the caller does not have the superadmin role.
        fn assert_only_superadmin(self: @ContractState) {
            let caller = get_caller_address();
            assert(self.has_superadmin_role(caller), Errors::ERR_NOT_A_SUPERADMIN)
        }
        /// Asserts that the caller is a deployed account.
        ///
        /// # Panics
        /// This function raises an error if the caller is not a deployed account
        fn assert_only_deployed_account(self: @ContractState) {
            let caller = get_caller_address();
            let is_deployed_account = self.is_deployed_account(caller);
            assert(is_deployed_account, Errors::ERR_CALLER_NOT_DEPLOYED_ACCOUNT);
        }

        /// Collects the deployment fee from the deployer, splits it, and emits an event.
        fn collect_deployment_fees(ref self: ContractState, deployer: ContractAddress) -> u256 {
            let fee_type = FeesType::DEPLOYMENT_FEE;
            let fee = self.get_fee(fee_type, deployer);
            let fee_token = self.get_fee_token();
            let percentage = self.deployment_fee_percentage.read();
            let spherre_contract = get_contract_address();

            // Stop execution if fee is zero or fee token is zero
            assert(fee.is_non_zero(), Errors::ERR_TOKEN_NOT_SET);
            assert(fee_token.is_non_zero(), Errors::ERR_FEE_NOT_SET);

            // Calculate shares
            let account_share = (fee * percentage.into()) / 10000_u256;
            let spherre_share = fee - account_share;


            // Transfer spherre_share to the contract
            // After deployment, transfer account_share to the new account
            let transfer_success = IERC20Dispatcher { contract_address: fee_token }
            .transfer_from(deployer, spherre_contract, fee);
            assert(transfer_success, Errors::ERR_ERC20_TRANSFER_FAILED);

            // Emit event (account_share will be routed to the new account after deployment)
            self.emit(DeploymentFeeCollected {
                sender: deployer,
                amount: fee,
                spherre_share,
                account_share,
                fee_token,
                timestamp: get_block_timestamp(),
            });

            account_share
        }
    }
}
