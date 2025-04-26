#[starknet::contract]
pub mod MockContract {
    use AccountData::InternalTrait;
    use core::traits::TryInto;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use spherre::account_data::AccountData;
    use spherre::components::permission_control::PermissionControl;
    use spherre::types::Transaction;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ClassHash, ContractAddress, get_caller_address};

    component!(path: AccountData, storage: account_data, event: AccountDataEvent);
    component!(path: PermissionControl, storage: permission_control, event: PermissionControlEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    pub impl AccountDataImpl = AccountData::AccountDataComponent<ContractState>;
    pub impl AccountDataInternalImpl = AccountData::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    pub impl PermissionControlImpl =
        PermissionControl::PermissionControl<ContractState>;
    pub impl PermissionControlInternalImpl = PermissionControl::InternalImpl<ContractState>;

    // Implement the Upgradeable component
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        deployer: ContractAddress,
        #[substorage(v0)]
        pub account_data: AccountData::Storage,
        #[substorage(v0)]
        pub permission_control: PermissionControl::Storage,
        #[substorage(v0)]
        pub upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        AccountDataEvent: AccountData::Event,
        PermissionControlEvent: PermissionControl::Event,
        UpgradeableEvent: UpgradeableComponent::Event,
        ContractUpgraded: ContractUpgradedEvent,
    }

    #[derive(Drop, starknet::Event)]
    struct ContractUpgradedEvent {
        deployer: ContractAddress,
        new_class_hash: ClassHash,
    }

    #[constructor]
    fn constructor(ref self: ContractState, deployer: ContractAddress) {
        // Store the deployer address
        self.deployer.write(deployer);
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            let caller = get_caller_address();
            let deployer = self.deployer.read();
            assert(deployer == caller, 'Only deployer can upgrade');
            let zero_class_hash: ClassHash = 0.try_into().unwrap();
            assert(new_class_hash != zero_class_hash, 'Invalid class hash');

            self.upgradeable.upgrade(new_class_hash);

            // Emit the upgrade event
            self
                .emit(
                    Event::ContractUpgraded(
                        ContractUpgradedEvent {
                            deployer: deployer, new_class_hash: new_class_hash,
                        },
                    ),
                );
        }
    }

    fn get_members(self: @ContractState) -> Array<ContractAddress> {
        let members = self.account_data.get_account_members();
        members
    }

    fn get_members_count(self: @ContractState) -> u64 {
        self.account_data.members_count.read()
    }

    fn get_deployer(self: @ContractState) -> ContractAddress {
        self.deployer.read()
    }

    #[generate_trait]
    pub impl PrivateImpl of PrivateTrait {
        fn set_threshold(ref self: ContractState, val: u64) {
            self.account_data.set_threshold(val);
        }
        fn get_threshold(self: @ContractState) -> (u64, u64) {
            self.account_data.get_threshold()
        }
        fn edit_member_count(ref self: ContractState, val: u64) {
            self.account_data.members_count.write(val);
        }

        // Expose the main contract's get_transaction function
        fn get_transaction(self: @ContractState, transaction_id: u256) -> Transaction {
            self.account_data.get_transaction(transaction_id)
        }
        fn get_number_of_voters(self: @ContractState) -> u64 {
            self.account_data.get_number_of_voters()
        }

        fn get_number_of_proposers(self: @ContractState) -> u64 {
            self.account_data.get_number_of_proposers()
        }

        fn get_number_of_executors(self: @ContractState) -> u64 {
            self.account_data.get_number_of_executors()
        }
        fn set_voter_permission(ref self: ContractState, member: ContractAddress) {
            self.permission_control.assign_voter_permission(member);
        }

        fn set_proposer_permission(ref self: ContractState, member: ContractAddress) {
            self.permission_control.assign_proposer_permission(member);
        }

        fn set_executor_permission(ref self: ContractState, member: ContractAddress) {
            self.permission_control.assign_executor_permission(member);
        }
    }
}
