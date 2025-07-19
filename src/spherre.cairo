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
        // --- Fee management ---
        fee_amounts: Map<FeesType, u256>,
        fee_token_address: ContractAddress,
        fee_enabled: Map<FeesType, bool>,
        // Fee collection statistics
        // (fees_type, fees_token, account) -> amount collected
        fee_collection_amounts: Map<(FeesType, ContractAddress, ContractAddress), u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AccountDeployed: AccountDeployed,
        AccountClassHashUpdated: AccountClassHashUpdated,
        FeeUpdated: FeeUpdated,
        FeeTokenUpdated: FeeTokenUpdated,
        FeeCollected: FeeCollected,
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

            let class_hash = self.account_class_hash.read();
            // Check that the Classhash is set

            assert(!class_hash.is_zero(), Errors::ERR_ACCOUNT_CLASSHASH_UNKNOWN);
            // Generate unique salt from blocktimestamp and block number
            let salt = PoseidonTrait::new()
                .update_with(get_block_timestamp())
                .update_with(get_block_number())
                .finalize();

            // TODO: Add the functionality to collect deployment fees

            // Serialize the argument for the deployment
            let mut calldata: Array<felt252> = array![];
            let deployer = get_contract_address();
            deployer.serialize(ref calldata);
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

            // Emit AccountDeployed event
            let event = AccountDeployed {
                account_address,
                owner,
                name,
                description,
                members,
                threshold,
                deployer,
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
    }
}
