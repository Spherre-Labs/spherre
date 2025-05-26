#[starknet::component]
pub mod MemberRemoveTransaction {
    use spherre::account_data::AccountData::InternalImpl as AccountDataInternalImpl;
    use spherre::account_data;
    use spherre::interfaces::iaccount_data::IAccountData;
    use spherre::interfaces::imember_tx::IMemberRemoveTransaction;
    use openzeppelin_security::PausableComponent::InternalImpl as PausableInternalImpl;
    use openzeppelin_security::pausable::PausableComponent;
    use spherre::components::permission_control;
    use spherre::errors::Errors;
    use spherre::types::MemberRemoveData;
    use spherre::types::TransactionType;
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry, Vec, VecTrait,
        MutableVecTrait
    };
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};

    #[storage]
    pub struct Storage {
        member_removal_transactions: Map<u256, MemberRemoveData>,
        pending_removal_transaction_ids: Vec<u256>,
        member_pending_removal: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        MemberRemovalProposed: MemberRemovalProposed,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MemberRemovalProposed {
        #[key]
        pub transaction_id: u256,
        #[key]
        pub member_to_remove: ContractAddress,
        #[key]
        pub proposer: ContractAddress,
        pub timestamp: u64,
    }


    #[embeddable_as(MemberRemoveTransactionImpl)]
    pub impl MemberRemoveTransactionComponentImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl AccountData: account_data::AccountData::HasComponent<TContractState>,
        impl PermissionControl: permission_control::PermissionControl::HasComponent<TContractState>,
        impl Pausable: PausableComponent::HasComponent<TContractState>,
    > of IMemberRemoveTransaction<ComponentState<TContractState>> {
        fn propose_remove_member_transaction(
            ref self: ComponentState<TContractState>, member_address: ContractAddress
        ) -> u256 {
            let caller = get_caller_address();

            // Validate caller cannot remove themselves
            assert(caller != member_address, Errors::CANNOT_REMOVE_SELF);

            // Get the component states
            let mut account_data_comp = get_dep_component_mut!(ref self, AccountData);

            // Check if member is already in pending removal process
            assert(
                !self.member_pending_removal.entry(member_address).read(),
                Errors::MEMBER_ALREADY_PENDING_REMOVAL
            );

            // Create transaction through AccountData component (validates proposer permission)
            let transaction_id = account_data_comp
                .create_transaction(TransactionType::MEMBER_REMOVE);

            // Create the member removal transaction
            let member_removal_transaction = MemberRemoveData {
                member_address,
                transaction_id,
                proposer: caller,
                created_at: get_block_timestamp(),
                is_executed: false,
            };

            // Store the transaction
            self
                .member_removal_transactions
                .entry(transaction_id)
                .write(member_removal_transaction);

            // Add to pending transactions list
            self.pending_removal_transaction_ids.append().write(transaction_id);

            // Mark member as pending removal to prevent duplicate proposals
            self.member_pending_removal.entry(member_address).write(true);

            // Emit event
            self
                .emit(
                    MemberRemovalProposed {
                        transaction_id,
                        member_to_remove: member_address,
                        proposer: caller,
                        timestamp: get_block_timestamp(),
                    }
                );

            transaction_id
        }

        fn get_member_removal_transaction(
            self: @ComponentState<TContractState>, transaction_id: u256
        ) -> MemberRemoveData {
            let transaction = self.member_removal_transactions.entry(transaction_id).read();

            // Validate transaction exists (check if transaction_id is non-zero)
            assert(transaction.transaction_id != 0, Errors::TRANSACTION_NOT_FOUND);

            transaction
        }

        fn member_removal_transaction_list(self: @ComponentState<TContractState>) -> Array<u256> {
            let mut transaction_ids = ArrayTrait::new();
            let pending_count = self.pending_removal_transaction_ids.len();

            let mut i = 0;
            loop {
                if i >= pending_count {
                    break;
                }

                let transaction_id = self.pending_removal_transaction_ids.at(i).read();
                let transaction = self.member_removal_transactions.entry(transaction_id).read();

                // Only include non-executed transactions
                if !transaction.is_executed {
                    transaction_ids.append(transaction_id);
                }

                i += 1;
            };

            transaction_ids
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// Execute the member removal transaction (called after approval threshold is met)
        fn execute_member_removal(ref self: ComponentState<TContractState>, transaction_id: u256) {
            let mut transaction = self.member_removal_transactions.entry(transaction_id).read();
            assert(!transaction.is_executed, 'Transaction already executed');

            // Mark as executed
            transaction.is_executed = true;
            self.member_removal_transactions.entry(transaction_id).write(transaction);

            // Clear pending removal flag
            self.member_pending_removal.entry(transaction.member_address).write(false);
            // Remove from pending list would require rebuilding the Vec
        // This is typically handled by filtering during reads or periodic cleanup
        }

        /// Check if a member is in pending removal process
        fn is_member_pending_removal(
            self: @ComponentState<TContractState>, member_address: ContractAddress
        ) -> bool {
            self.member_pending_removal.entry(member_address).read()
        }
    }
}
