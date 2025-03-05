#[starknet::component]
pub mod AccountData {
    use core::num::traits::Zero;
    use core::starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use spherre::errors::Errors;
    use spherre::interfaces::iaccount_data::IAccountData;
    use spherre::types::{TransactionStatus, TransactionType};
    use starknet::ContractAddress;

    #[storage]
    pub struct Storage {
        pub transactions: Map::<u256, Transaction>,
        pub tx_count: u256, // the transaction length
        pub threshold: u64, // the number of members required to approve a transaction for it to be executed
        pub members: Map::<u64, ContractAddress>, // Map(id, member) the members of the account
        pub members_count: u64 // the member length
    }

    #[starknet::storage_node]
    pub struct Transaction {
        id: u256,
        tx_type: TransactionType,
        tx_status: TransactionStatus,
        date_created: u64,
        date_executed: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AddedMember: AddedMember,
        ThresholdUpdated: ThresholdUpdated,
    }

    #[derive(Drop, starknet::Event)]
    struct AddedMember {
        member: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ThresholdUpdated {
        threshold: u64,
        date_updated: u64,
    }

    #[embeddable_as(AccountDataComponent)]
    pub impl AccountDataImpl<
        TContractState, +HasComponent<TContractState>,
    > of IAccountData<ComponentState<TContractState>> {
        fn get_account_members(self: @ComponentState<TContractState>) -> Array<ContractAddress> {
            let mut members_of_account: Array<ContractAddress> = array![];
            let no_of_members = self.members_count.read();

            let mut i = 0;

            while i <= no_of_members {
                let current_member = self.members.entry(i).read();
                members_of_account.append(current_member);

                i += 1;
            };

            members_of_account
        }

        fn get_members_count(self: @ComponentState<TContractState>) -> u64 {
            self.members_count.read()
        }

        fn add_member(ref self: ComponentState<TContractState>, address: ContractAddress) {
            self._add_member(address);
        }
        //This takes no arguments and returns a tuple in which the first member is a threshold and
        //the second is members_count of an account
        fn get_threshold(self: @ComponentState<TContractState>) -> (u64, u64) {
            let threshold: u64 = self.threshold.read();
            let members_count: u64 = self.members_count.read();
            (threshold, members_count)
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

        ///This is a private function that sets a threshold agter asserting threshold <
        ///members_count
        fn set_threshold(ref self: ComponentState<TContractState>, threshold: u64) {
            let members_count: u64 = self.members_count.read();
            assert(threshold <= members_count, Errors::ThresholdError);
            self.threshold.write(threshold);
        }
    }
}

