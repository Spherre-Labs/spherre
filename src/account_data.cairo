#[starknet::component]
pub mod AccountData {

    use core::num::traits::Zero;
    use core::starknet::storage::{
        Map, StorageMapReadAccess, StoragePathEntry, StoragePointerReadAccess,
        StoragePointerWriteAccess, Vec, VecTrait,
    };
    use openzeppelin_security::PausableComponent::InternalImpl as PausableInternalImpl;
    use openzeppelin_security::pausable::PausableComponent;
    use spherre::components::permission_control;
    use spherre::errors::Errors;
    use spherre::interfaces::iaccount_data::IAccountData;
    use spherre::interfaces::ipermission_control::IPermissionControl;
    use spherre::types::{TransactionStatus, TransactionType, Transaction, Permissions};
    use starknet::storage::MutableVecTrait;
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};

    #[storage]
    pub struct Storage {
        pub transactions: Map<u256, StorageTransaction>,
        pub tx_count: u256, // the transaction length
        pub threshold: u64, // the number of members required to approve a transaction for it to be executed
        pub members: Map::<u64, ContractAddress>, // Map(id, member) the members of the account
        pub members_count: u64, // the member length
        pub has_voted: Map<(u256, ContractAddress), bool>, // Map(tx_id, member) -> bool
        pub transaction_rejectors: Map<ContractAddress, u256> // Map(member that rejected) -> tx_id
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
        TransactionApproved: TransactionApproved,
        TransactionRejected: TransactionRejected,
        TransactionVoted: TransactionVoted,
        TransactionExecuted: TransactionExecuted,
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


    #[derive(Drop, starknet::Event)]
    pub struct TransactionVoted {
        #[key]
        transaction_id: u256,
        #[key]
        voter: ContractAddress,
        date_voted: u64
    }

    #[derive(Drop, starknet::Event)]
    pub struct TransactionApproved {
        #[key]
        transaction_id: u256,
        date_approved: u64
    }

    #[derive(Drop, starknet::Event)]
    pub struct TransactionRejected {
        #[key]
        transaction_id: u256,
        date_approved: u64
    }

    #[derive(Drop, starknet::Event)]
    pub struct TransactionExecuted {
        #[key]
        transaction_id: u256,
        #[key]
        executor: ContractAddress,
        date_executed: u64
    }

    #[embeddable_as(AccountData)]
    pub impl AccountDataImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl PermissionControl: permission_control::PermissionControl::HasComponent<TContractState>,
        impl Pausable: PausableComponent::HasComponent<TContractState>,
    > of IAccountData<ComponentState<TContractState>> {
        fn get_account_members(self: @ComponentState<TContractState>) -> Array<ContractAddress> {
            let mut members_of_account: Array<ContractAddress> = array![];
            let no_of_members = self.members_count.read();

            let mut i = 0;

            while i <= no_of_members {
                let current_member = self.members.entry(i).read();
                members_of_account.append(current_member);

                i += 1;
            }

            members_of_account
        }

        fn get_members_count(self: @ComponentState<TContractState>) -> u64 {
            self.members_count.read()
        }

        //This takes no arguments and returns a tuple where the first member is the threshold and
        //the second is the members_count of the account
        fn get_threshold(self: @ComponentState<TContractState>) -> (u64, u64) {
            let threshold: u64 = self.threshold.read();
            let members_count: u64 = self.members_count.read();
            (threshold, members_count)
        }

        fn get_transaction(
            self: @ComponentState<TContractState>, transaction_id: u256,
        ) -> Transaction {
            // Check if transaction ID is within valid range
            self.assert_valid_transaction(transaction_id);

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
            }
            let approved_span = approved_array.span();

            // Convert rejected Vec<ContractAddress> to Span<ContractAddress>
            let rejected_len = storage_path.rejected.len();
            let mut rejected_array = ArrayTrait::new();
            i = 0;
            while i < rejected_len {
                let address = storage_path.rejected.at(i).read(); // Read the ContractAddress
                rejected_array.append(address);
                i += 1;
            }
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
            }

            found
        }
        fn get_number_of_voters(self: @ComponentState<TContractState>) -> u64 {
            let permission_control_comp = get_dep_component!(self, PermissionControl);
            let mut counter: u64 = 0;
            let no_of_members = self.members_count.read();
            for index in 0
                ..no_of_members {
                    let member = self.members.entry(index).read();
                    if permission_control_comp.has_permission(member, Permissions::VOTER) {
                        counter = counter + 1;
                    }
                };
            counter
        }
        fn get_number_of_proposers(self: @ComponentState<TContractState>) -> u64 {
            let permission_control_comp = get_dep_component!(self, PermissionControl);
            let mut counter: u64 = 0;
            let no_of_members = self.members_count.read();
            for index in 0
                ..no_of_members {
                    let member = self.members.entry(index).read();
                    if permission_control_comp.has_permission(member, Permissions::PROPOSER) {
                        counter = counter + 1;
                    }
                };
            counter
        }
        fn get_number_of_executors(self: @ComponentState<TContractState>) -> u64 {
            let permission_control_comp = get_dep_component!(self, PermissionControl);
            let mut counter: u64 = 0;
            let no_of_members = self.members_count.read();
            for index in 0
                ..no_of_members {
                    let member = self.members.entry(index).read();
                    if permission_control_comp.has_permission(member, Permissions::EXECUTOR) {
                        counter = counter + 1;
                    }
                };
            counter
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl PermissionControl: permission_control::PermissionControl::HasComponent<TContractState>,
        impl Pausable: PausableComponent::HasComponent<TContractState>,
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


        fn set_threshold(ref self: ComponentState<TContractState>, threshold: u64) {
            // PAUSE GUARD
            let pausable = get_dep_component!(@self, Pausable);
            pausable.assert_not_paused();

            let members_count: u64 = self.members_count.read();
            assert(threshold <= members_count, Errors::ThresholdError);
            self.threshold.write(threshold);
        }
        // Initialize a transaction with a transaction type and return the id
        // @params tx_type: The type of the transaction
        // Returns: (u256) The transaction id
        fn create_transaction(
            ref self: ComponentState<TContractState>, tx_type: TransactionType
        ) -> u256 {
            // PAUSE GUARD
            let pausable = get_dep_component!(@self, Pausable);
            pausable.assert_not_paused();

            let caller = get_caller_address();
            // check if the caller is a member
            assert(self.is_member(caller), Errors::ERR_NOT_MEMBER);
            // check if the caller has the proposer permission
            let permission_control_comp = get_dep_component!(@self, PermissionControl);
            assert(
                permission_control_comp.has_permission(caller, Permissions::PROPOSER),
                Errors::ERR_NOT_PROPOSER
            );

            // increment the id
            let transaction_id = self.tx_count.read() + 1;

            // create the transaction
            let transaction = self.transactions.entry(transaction_id);
            transaction.id.write(transaction_id);
            transaction.tx_type.write(tx_type);
            transaction.tx_status.write(TransactionStatus::INITIATED);
            transaction.proposer.write(caller);
            transaction.date_created.write(get_block_timestamp());

            // update the transaction count
            self.tx_count.write(transaction_id);
            transaction_id
        }
        // Approve a transaction
        // @params tx_id: The transaction id
        // @params caller: The approver
        fn approve_transaction(
            ref self: ComponentState<TContractState>, tx_id: u256, caller: ContractAddress
        ) {
            // PAUSE GUARD
            let pausable = get_dep_component!(@self, Pausable);
            pausable.assert_not_paused();

            // check if caller can vote
            self.assert_caller_can_vote(tx_id, caller);

            // update has_voted map to prevent double voting
            self.has_voted.entry((tx_id, caller)).write(true);

            // get the transaction
            let transaction = self.transactions.entry(tx_id);
            // add the caller to the list of approvers
            transaction.approved.append().write(caller);

            let approvers_length = transaction.approved.len();
            let (threshold, _) = self.get_threshold();
            let timestamp = get_block_timestamp();

            // check if approval threshold has been reached and updated
            // the transaction status if that is the case.
            if approvers_length >= threshold {
                transaction.tx_status.write(TransactionStatus::APPROVED);
                self.emit(TransactionApproved { transaction_id: tx_id, date_approved: timestamp });
            }
            self
                .emit(
                    TransactionVoted { transaction_id: tx_id, voter: caller, date_voted: timestamp }
                )
        }

        fn reject_transaction(
            ref self: ComponentState<TContractState>, tx_id: u256, caller: ContractAddress
        ) {
            // check if caller can vote
            self.assert_caller_can_vote(tx_id, caller);

            // update has_voted map to prevent double voting
            self.has_voted.entry((tx_id, caller)).write(true);

            // get the transaction
            let transaction = self.transactions.entry(tx_id);
            // add the caller to the list of approvers
            transaction.rejected.append().write(caller);

            let rejectors_length = transaction.rejected.len();
            let approved_length = transaction.approved.len();
            let no_of_possible_voters = self.get_number_of_voters();
            let members_that_have_voted = approved_length + rejectors_length;
            let not_voted_yet = no_of_possible_voters - members_that_have_voted;
            let max_possible_approved_length = approved_length + not_voted_yet;
            let (threshold, _) = self.get_threshold();
            let timestamp = get_block_timestamp();
            // check if approval threshold has been reached and update
            // the transaction status if that is the case.
            // According to issue description, transaction is automatically
            // rejected in any other case

            if max_possible_approved_length < threshold {
                transaction.tx_status.write(TransactionStatus::REJECTED);
                self.emit(TransactionRejected { transaction_id: tx_id, date_approved: timestamp });
            }

            self
                .emit(
                    TransactionVoted { transaction_id: tx_id, voter: caller, date_voted: timestamp }
                )
        }

        fn execute_transaction(
            ref self: ComponentState<TContractState>, transaction_id: u256, caller: ContractAddress
        ) {
            self.assert_valid_transaction(transaction_id);
            let transaction = self.transactions.entry(transaction_id);
            assert(
                transaction.tx_status.read() == TransactionStatus::APPROVED,
                Errors::ERR_TRANSACTION_NOT_EXECUTABLE
            );
            assert(self.is_member(caller), Errors::ERR_NOT_MEMBER);

            let permission_control_comp = get_dep_component!(@self, PermissionControl);
            assert(
                permission_control_comp.has_permission(caller, Permissions::EXECUTOR),
                Errors::ERR_NOT_EXECUTOR
            );

            transaction.tx_status.write(TransactionStatus::EXECUTED);
            let timestamp = get_block_timestamp();
            transaction.date_executed.write(timestamp);
            transaction.executor.write(caller);

            self
                .emit(
                    TransactionExecuted {
                        transaction_id: transaction_id, executor: caller, date_executed: timestamp,
                    }
                );
        }

        fn _update_transaction_status(
            ref self: ComponentState<TContractState>,
            transaction_id: u256,
            status: TransactionStatus
        ) {
            self.assert_valid_transaction(transaction_id);
            self.transactions.entry(transaction_id).tx_status.write(status);
        }

        fn assert_valid_transaction(self: @ComponentState<TContractState>, transaction_id: u256) {
            let tx_count = self.tx_count.read();
            assert(transaction_id <= tx_count, Errors::ERR_INVALID_TRANSACTION);
            assert(transaction_id != 0, Errors::ERR_INVALID_TRANSACTION);
        }
        fn assert_is_votable_transaction(
            self: @ComponentState<TContractState>, transaction_id: u256
        ) {
            self.assert_valid_transaction(transaction_id);
            let transaction = self.transactions.entry(transaction_id);
            assert(
                transaction.tx_status.read() == TransactionStatus::INITIATED,
                Errors::ERR_TRANSACTION_NOT_VOTABLE
            );
        }
        fn assert_caller_can_vote(
            self: @ComponentState<TContractState>, transaction_id: u256, caller: ContractAddress
        ) {
            // check for transaction validity
            // check if transaction in range
            self.assert_valid_transaction(transaction_id);
            // check if transaction is votable
            self.assert_is_votable_transaction(transaction_id);
            // check if the caller is a member
            assert(self.is_member(caller), Errors::ERR_NOT_MEMBER);
            // check if the caller has the voter permission
            let permission_control_comp = get_dep_component!(self, PermissionControl);
            assert(
                permission_control_comp.has_permission(caller, Permissions::VOTER),
                Errors::ERR_NOT_VOTER
            );
            // check that member has not voted
            assert(
                !self.has_voted.entry((transaction_id, caller)).read(),
                Errors::ERR_CALLER_CANNOT_VOTE
            );
        }
    }
}

