#[starknet::component]
pub mod AccountData {
    use alexandria_storage::list::{ListTrait, List};
    use core::num::traits::Zero;
    use core::starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
    };
    use spherre::errors::Errors;
    use spherre::interfaces::iaccount_data::IAccountData;
    use spherre::types::{TransactionStatus, TransactionType, Transaction};
    use starknet::ContractAddress;

    #[storage]
    pub struct Storage {
        pub transactions: Map::<u256, StorageTransaction>,
        pub tx_count: u256, // the transaction length
        pub threshold: u64, // the number of members required to approve a transaction for it to be executed
        pub members: Map::<u64, ContractAddress>, // Map(id, member) the members of the account
        pub members_count: u64 // the member length
    }

    #[starknet::storage_node]
    pub struct StorageTransaction {
        pub id: u256,
        pub tx_type: TransactionType,
        pub tx_status: TransactionStatus,
        pub proposer: ContractAddress,
        pub executor: ContractAddress,
        pub approved: Vec<ContractAddress>,
        pub rejected: Vec<ContractAddress>,
        pub date_created: u64,
        pub date_executed: u64,
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

        fn get_transaction(
            self: @ComponentState<TContractState>, transaction_id: u256
        ) -> Transaction {
            // Check if transaction ID is within valid range
            let tx_count = self.tx_count.read();
            assert(transaction_id < tx_count, 'Transaction ID out of range');

            // Access the storage entry for the given transaction ID
            let storage_path = self.transactions.entry(transaction_id);

            // Read each field of the StorageTransaction individually (cos u cant read from
            // storagenodes directly)
            let id = storage_path.id.read();
            let tx_type = storage_path.tx_type.read();
            let tx_status = storage_path.tx_status.read();
            let proposer = storage_path.proposer.read();
            let executor = storage_path.executor.read();
            let date_created = storage_path.date_created.read();
            let date_executed = storage_path.date_executed.read();

            // Convert approved Vec<ContractAddress> to Span<ContractAddress>
            let approved_len = storage_path.approved.len();
            let mut approved_array = ArrayTrait::new();
            let mut i = 0;
            while i < approved_len {
                let address = storage_path.approved.at(i).read(); // Read the ContractAddress
                approved_array.append(address);
                i += 1;
            };
            let approved_span = approved_array.span();

            // Convert rejected Vec<ContractAddress> to Span<ContractAddress>
            let rejected_len = storage_path.rejected.len();
            let mut rejected_array = ArrayTrait::new();
            i = 0;
            while i < rejected_len {
                let address = storage_path.rejected.at(i).read(); // Read the ContractAddress
                rejected_array.append(address);
                i += 1;
            };
            let rejected_span = rejected_array.span();

            // return the Transaction struct
            Transaction {
                id,
                tx_type,
                tx_status,
                proposer,
                executor,
                approved: approved_span,
                rejected: rejected_span,
                date_created,
                date_executed,
            }
        }

        /// Checks if a given address is a member of the account
        fn is_member(self: @ComponentState<TContractState>, address: ContractAddress) -> bool {
            let no_of_members = self.members_count.read();
            let mut i = 0;
            let mut found = false;

            while i < no_of_members {
                let current_member = self.members.entry(i).read();
                if current_member == address {
                    found = true;
                }
                i += 1;
            };

            found
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

