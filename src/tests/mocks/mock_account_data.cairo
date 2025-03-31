#[starknet::contract]
pub mod MockContract {
    use AccountData::InternalTrait;
    use spherre::account_data::AccountData;
    use spherre::types::Transaction;
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess,};

    component!(path: AccountData, storage: account_data, event: AccountDataEvent);

    #[abi(embed_v0)]
    pub impl AccountDataImpl = AccountData::AccountData<ContractState>;
    pub impl AccountDataInternalImpl = AccountData::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub account_data: AccountData::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        AccountDataEvent: AccountData::Event,
    }


    #[generate_trait]
    pub impl PrivateImpl of PrivateTrait {
        fn is_member(self: @ContractState, member: ContractAddress) -> bool {
            self.account_data.is_member(member)
        }
        fn get_members(self: @ContractState) -> Array<ContractAddress> {
            let members = self.account_data.get_account_members();
            members
        }

        fn get_members_count(self: @ContractState) -> u64 {
            self.account_data.members_count.read()
        }
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

        fn add_member(ref self: ContractState, member: ContractAddress) {
            self.account_data._add_member(member);
        }
    }
}
