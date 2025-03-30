#[starknet::contract]
pub mod MockContract {
    use AccountData::InternalTrait;
    use spherre::account_data::AccountData;
    use spherre::components::permission_control::PermissionControl;
    use spherre::types::Transaction;
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    component!(path: AccountData, storage: account_data, event: AccountDataEvent);
    component!(path: PermissionControl, storage: permission_control, event: PermissionControlEvent);

    #[abi(embed_v0)]
    pub impl AccountDataImpl = AccountData::AccountDataComponent<ContractState>;
    pub impl AccountDataInternalImpl = AccountData::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    pub impl PermissionControlImpl =
        PermissionControl::PermissionControl<ContractState>;
    pub impl PermissionControlInternalImpl = PermissionControl::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub account_data: AccountData::Storage,
        #[substorage(v0)]
        pub permission_control: PermissionControl::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        AccountDataEvent: AccountData::Event,
        PermissionControlEvent: PermissionControl::Event,
    }

    fn get_members(self: @ContractState) -> Array<ContractAddress> {
        let members = self.account_data.get_account_members();
        members
    }

    fn get_members_count(self: @ContractState) -> u64 {
        self.account_data.members_count.read()
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
