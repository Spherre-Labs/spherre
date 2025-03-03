#[starknet::component]
pub mod AccountData {
    use core::num::traits::Zero;
    use core::starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use spherre::interfaces::iaccount_data::IAccountData;
    use spherre::types::{TransactionStatus, TransactionType};
    use starknet::ContractAddress;
    #[storage]
    pub struct Storage {
        transactions: Map::<u256, Transaction>,
        tx_count: u256, // the transaction length
        threshold: u64, // the number of members required to approve a transaction for it to be executed
        members: Map::<u64, ContractAddress>, // Map(id, member) the members of the account
        members_count: u64 // the member length
    }

    #[starknet::storage_node]
    pub struct Transaction {
        id: u256,
        tx_type: TransactionType,
        tx_status: TransactionStatus,
        date_created: u64,
        date_executed: u64,
    }

    #[embeddable_as(AccountDataComponent)]
    impl AccountDataImpl<
        TContractState, +HasComponent<TContractState>,
    > of IAccountData<ComponentState<TContractState>> {
        fn get_account_members(self: @ComponentState<TContractState>) -> Array<ContractAddress> {
            let mut members_of_account: Array<ContractAddress> = array![];
            let no_of_members = self.members_count.read();

            let mut i = 1;

            while i < no_of_members + 1 {
                let current_member = self.members.entry(i).read();
                members_of_account.append(current_member);

                i += 1;
            };

            members_of_account
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn _add_member(ref self: ComponentState<TContractState>, address: ContractAddress) {
            assert(!address.is_zero(), 'Zero Address Caller');
            let mut current_members = self.members_count.read();
            self.members.entry(current_members).write(address);
            self.members_count.write(current_members + 1);
        }

        fn _get_members_count(self: @ComponentState<TContractState>) -> u64 {
            self.members_count.read()
        }
    }
}
