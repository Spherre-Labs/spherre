//! This module contains the AccountData component of Spherre
//! It manages account transactions, members, and voting mechanisms.
//! It provides functionality for adding members, setting thresholds, creating and executing
//! transactions, and handling approvals and rejections.
//!
//! The comment documentation of the public entrypoints can be found in the
//! `IAccountData` interface.

#[starknet::component]
pub mod AccountData {
    use core::num::traits::Zero;
    use core::starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
    };
    use openzeppelin_security::PausableComponent::InternalImpl as PausableInternalImpl;
    use openzeppelin_security::pausable::PausableComponent;
    use spherre::components::permission_control;
    use spherre::errors::Errors;
    use spherre::interfaces::iaccount::{IAccountDispatcher, IAccountDispatcherTrait};
    use spherre::interfaces::iaccount_data::IAccountData;
    use spherre::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use spherre::interfaces::ipermission_control::IPermissionControl;
    use spherre::interfaces::ispherre::{ISpherreDispatcher, ISpherreDispatcherTrait};
    use spherre::types::{
        TransactionStatus, TransactionType, Transaction, Permissions, MemberDetails, FeesType,
    };
    use starknet::storage::MutableVecTrait;
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp, get_contract_address};

    const DEFAULT_WILL_DURATION: u64 = 7776000; // 90 days in seconds

    #[storage]
    pub struct Storage {
        pub transactions: Map::<
            u256, StorageTransaction
        >, // Map(tx_id, StorageTransaction) the transactions of the account
        pub tx_count: u256, // the transaction length
        pub threshold: u64, // the number of members required to approve a transaction for it to be executed
        pub members: Map::<u64, ContractAddress>, // Map(id, member) the members of the account
        pub members_count: u64, // the member length
        pub has_voted: Map<(u256, ContractAddress), bool>, // Map(tx_id, member) -> bool
        pub transaction_rejectors: Map<ContractAddress, u256>, // Map(member that rejected) -> tx_id
        pub member_proposed_count: Map<ContractAddress, u256>,
        pub member_approved_count: Map<ContractAddress, u256>,
        pub member_rejected_count: Map<ContractAddress, u256>,
        pub member_executed_count: Map<ContractAddress, u256>,
        pub member_joined_date: Map<ContractAddress, u64>,
        // Smart Will storage
        pub smart_will_to_member: Map<ContractAddress, ContractAddress>,
        pub member_to_smart_will: Map<ContractAddress, ContractAddress>,
        pub member_to_will_duration: Map<ContractAddress, u64>,
        pub member_will_creation_time: Map<ContractAddress, u64>,
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
        // Smart Will events
        SmartWillUpdated: SmartWillUpdated,
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

    // TODO: Implement Transaction Proposed Event

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

    #[derive(Drop, starknet::Event)]
    pub struct SmartWillUpdated {
        #[key]
        member: ContractAddress,
        #[key]
        will_address: ContractAddress,
        duration: u64,
        creation_time: u64,
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
            };

            members_of_account
        }
        fn get_members_count(self: @ComponentState<TContractState>) -> u64 {
            self.members_count.read()
        }
        fn get_threshold(self: @ComponentState<TContractState>) -> (u64, u64) {
            let threshold: u64 = self.threshold.read();
            let members_count: u64 = self.members_count.read();
            (threshold, members_count)
        }
        fn get_transaction(
            self: @ComponentState<TContractState>, transaction_id: u256
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
        fn approve_transaction(ref self: ComponentState<TContractState>, tx_id: u256) {
            // PAUSE GUARD
            let pausable = get_dep_component!(@self, Pausable);
            pausable.assert_not_paused();

            // Validate member (with smart will support)
            let (member, _caller) = self.validate_member(get_caller_address());
            // check if caller can vote
            self.assert_caller_can_vote(tx_id, member);

            // update has_voted map to prevent double voting
            self.has_voted.entry((tx_id, member)).write(true);

            // get the transaction
            let transaction = self.transactions.entry(tx_id);
            // add the caller to the list of approvers
            transaction.approved.append().write(member);

            let approvers_length = transaction.approved.len();
            let (threshold, _) = self.get_threshold();
            let timestamp = get_block_timestamp();

            // Increment approver's count
            self._increment_approved_count(member);

            //TODO: Create a logic for when caller is the same as the member
            // Maybe emit and event that voting action was done by
            // the will address and not the member

            // check if approval threshold has been reached and updated
            // the transaction status if that is the case.
            if approvers_length >= threshold {
                transaction.tx_status.write(TransactionStatus::APPROVED);
                self.emit(TransactionApproved { transaction_id: tx_id, date_approved: timestamp });
            }
            // Collect Fee
            self.collect_fees(FeesType::VOTING_FEE);
            self
                .emit(
                    TransactionVoted { transaction_id: tx_id, voter: member, date_voted: timestamp }
                );
        }
        fn reject_transaction(ref self: ComponentState<TContractState>, tx_id: u256) {
            // PAUSE GUARD
            let pausable = get_dep_component!(@self, Pausable);
            pausable.assert_not_paused();

            // Validate member (with smart will support)
            let (member, _caller) = self.validate_member(get_caller_address());

            // check if caller can vote
            self.assert_caller_can_vote(tx_id, member);

            // update has_voted map to prevent double voting
            self.has_voted.entry((tx_id, member)).write(true);

            // get the transaction
            let transaction = self.transactions.entry(tx_id);
            // add the caller to the list of approvers
            transaction.rejected.append().write(member);

            let rejectors_length = transaction.rejected.len();
            let approved_length = transaction.approved.len();
            let no_of_possible_voters = self.get_number_of_voters();
            let members_that_have_voted = approved_length + rejectors_length;
            let not_voted_yet = no_of_possible_voters - members_that_have_voted;
            let max_possible_approved_length = approved_length + not_voted_yet;
            let (threshold, _) = self.get_threshold();
            let timestamp = get_block_timestamp();

            // Increment rejector's count
            self._increment_rejected_count(member);

            //TODO: Create a logic for when caller is the same as the member
            // Maybe emit and event that voting action was done by
            // the will address and not the member

            // check if approval threshold has been reached and update
            // the transaction status if that is the case.
            // According to issue description, transaction is automatically
            // rejected in any other case

            if max_possible_approved_length < threshold {
                transaction.tx_status.write(TransactionStatus::REJECTED);
                self.emit(TransactionRejected { transaction_id: tx_id, date_approved: timestamp });
            }
            // Collect Fee
            self.collect_fees(FeesType::VOTING_FEE);

            self
                .emit(
                    TransactionVoted { transaction_id: tx_id, voter: member, date_voted: timestamp }
                );
        }
        fn get_member_full_details(
            self: @ComponentState<TContractState>, member: ContractAddress
        ) -> MemberDetails {
            // Verify member exists
            assert(self.is_member(member), Errors::ERR_NOT_MEMBER);

            // Get all metrics from storage
            let proposed_count = self.member_proposed_count.entry(member).read();
            let approved_count = self.member_approved_count.entry(member).read();
            let rejected_count = self.member_rejected_count.entry(member).read();
            let executed_count = self.member_executed_count.entry(member).read();
            let date_joined = self.member_joined_date.entry(member).read();

            // Return populated MemberDetails struct
            MemberDetails {
                address: member,
                proposed_count,
                approved_count,
                rejected_count,
                executed_count,
                date_joined,
            }
        }
        fn update_smart_will(
            ref self: ComponentState<TContractState>, will_address: ContractAddress
        ) {
            // Get caller
            let caller = get_caller_address();

            // Validate caller is a member
            assert(self.is_member(caller), Errors::ERR_NOT_MEMBER);

            // Validate will conditions
            self.validate_will_conditions(caller, will_address);

            // Update storage maps
            // Get the current will address if any
            let current_will_address = self.member_to_smart_will.entry(caller).read();
            let current_time = get_block_timestamp();
            // Map the current will address to zero if it exists
            if current_will_address.is_non_zero() {
                // Remove the current will address from the smart_will_to_member map
                self.smart_will_to_member.entry(current_will_address).write(Zero::zero());
            }
            self.smart_will_to_member.entry(will_address).write(caller);
            self.member_to_smart_will.entry(caller).write(will_address);

            // If current will address is zero, it means this is the first time
            if current_will_address.is_zero() {
                self.member_will_creation_time.entry(caller).write(current_time);
                // Set default duration if first-time setup
                self
                    .member_to_will_duration
                    .entry(caller)
                    .write(current_time + DEFAULT_WILL_DURATION);
            }

            // Emit event
            self
                .emit(
                    SmartWillUpdated {
                        member: caller,
                        will_address,
                        duration: DEFAULT_WILL_DURATION,
                        creation_time: current_time
                    }
                );
        }

        fn get_member_will_address(
            self: @ComponentState<TContractState>, member: ContractAddress
        ) -> ContractAddress {
            assert(self.is_member(member), Errors::ERR_NOT_MEMBER);
            self.member_to_smart_will.entry(member).read()
        }

        fn get_member_will_duration(
            self: @ComponentState<TContractState>, member: ContractAddress
        ) -> u64 {
            assert(self.is_member(member), Errors::ERR_NOT_MEMBER);
            self.member_to_will_duration.entry(member).read()
        }

        fn get_remaining_will_time(
            self: @ComponentState<TContractState>, member: ContractAddress
        ) -> u64 {
            assert(self.is_member(member), Errors::ERR_NOT_MEMBER);

            let creation_time = self.member_will_creation_time.entry(member).read();
            if creation_time == 0 {
                return 0;
            }

            let duration = self.member_to_will_duration.entry(member).read();
            let current_time = get_block_timestamp();

            if current_time > duration {
                0
            } else {
                duration - current_time
            }
        }

        fn can_update_will(self: @ComponentState<TContractState>, member: ContractAddress) -> bool {
            // Verify member exists
            assert(self.is_member(member), Errors::ERR_NOT_MEMBER);

            // Get creation time - if 0, no will exists
            let creation_time = self.member_will_creation_time.entry(member).read();
            if creation_time == 0 {
                return true;
            }
            let current_time = get_block_timestamp();
            // Check if duration has elapsed
            let duration = self.member_to_will_duration.entry(member).read();
            if current_time < duration {
                true
            } else {
                false
            }
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
        /// Adds a member to the account
        /// This function adds a member to the account
        ///
        /// # Parameters
        /// * `address` - The contract address of the member to be added
        ///
        /// # Panics
        /// It raises an error if the address is zero.
        fn _add_member(ref self: ComponentState<TContractState>, address: ContractAddress) {
            assert(!address.is_zero(), 'Zero Address Caller');
            let mut current_members = self.members_count.read();
            self.members.entry(current_members).write(address);
            self.members_count.write(current_members + 1);

            // Initialize member metrics
            self.member_proposed_count.entry(address).write(0);
            self.member_approved_count.entry(address).write(0);
            self.member_rejected_count.entry(address).write(0);
            self.member_executed_count.entry(address).write(0);
            self.member_joined_date.entry(address).write(get_block_timestamp());

            // Emit event
            self.emit(AddedMember { member: address });
        }
        /// Removes a member from the account
        /// This function removes a member from the account
        ///
        /// # Parameters
        /// * `address` - The contract address of the member to be removed
        ///
        /// # Panics
        /// It raises an error if the address is zero.
        /// It raises an error if the address is not a member of the account.
        fn remove_member(ref self: ComponentState<TContractState>, address: ContractAddress) {
            assert(!address.is_zero(), 'Zero Address Caller');
            let mut current_members = self.members_count.read();
            let mut i = 0;
            let mut found = false;

            while i < current_members {
                let current_member = self.members.entry(i).read();
                if current_member == address {
                    found = true;
                    break;
                }
                i += 1;
            };

            assert(found, Errors::ERR_NOT_MEMBER);
            // Swaps the found member with the last member
            // and removes the last member
            if i < current_members - 1 {
                let last_member = self.members.entry(current_members - 1).read();
                self
                    .members
                    .entry(i)
                    .write(last_member); // Overwrite the found member with the last member
            }
            self
                .members
                .entry(current_members - 1)
                .write(Zero::zero()); // Clear the last member's slot
            // decrement the members count
            self.members_count.write(current_members - 1);
        }
        /// Gets the number of members in the account
        ///
        /// # Returns
        /// The number of members in the account
        fn _get_members_count(self: @ComponentState<TContractState>) -> u64 {
            self.members_count.read()
        }
        /// Sets the threshold for the number of members required to approve a transaction
        ///
        /// # Parameters
        /// * `threshold` - The number of members required to approve a transaction
        ///
        /// # Panics
        /// It raises an error if the threshold is greater than the number of members.
        /// It raises an error if the contract is paused.
        /// It raises an error if the threshold is zero.
        fn set_threshold(ref self: ComponentState<TContractState>, threshold: u64) {
            // PAUSE GUARD
            let pausable = get_dep_component!(@self, Pausable);
            pausable.assert_not_paused();

            let members_count: u64 = self.members_count.read();
            assert(threshold <= members_count, Errors::ThresholdError);
            assert(threshold > 0, Errors::NON_ZERO_THRESHOLD);
            self.threshold.write(threshold);
        }
        /// Create (Initialize) a transaction with a transaction type and return the id
        /// This function creates a transaction with the given type and returns the transaction id.
        ///
        /// # Parameters
        /// * `tx_type` - The type of the transaction to be created
        ///
        /// # Panics
        /// It raises an error if the contract is paused.
        /// It raises an error if the caller is not a member of the account.
        /// It raises an error if the caller does not have the proposer permission.
        fn create_transaction(
            ref self: ComponentState<TContractState>, tx_type: TransactionType
        ) -> u256 {
            // PAUSE GUARD
            let pausable = get_dep_component!(@self, Pausable);
            pausable.assert_not_paused();

            // Validate member (with smart will support)
            let (member, _caller) = self.validate_member(get_caller_address());
            // check if the caller has the proposer permission
            let permission_control_comp = get_dep_component!(@self, PermissionControl);
            assert(
                permission_control_comp.has_permission(member, Permissions::PROPOSER),
                Errors::ERR_NOT_PROPOSER
            );

            // increment the id
            let transaction_id = self.tx_count.read() + 1;

            // create the transaction
            let transaction = self.transactions.entry(transaction_id);
            transaction.id.write(transaction_id);
            transaction.tx_type.write(tx_type);
            transaction.tx_status.write(TransactionStatus::INITIATED);
            transaction.proposer.write(member);
            transaction.date_created.write(get_block_timestamp());

            // update the transaction count
            self.tx_count.write(transaction_id);

            // Increment proposer's count
            self._increment_proposed_count(member);

            // Collect Fee
            self.collect_fees(FeesType::PROPOSAL_FEE);

            transaction_id
        }
        /// Executes a transaction by its ID
        /// This function allows a member with the executor permission to execute a transaction.
        ///
        /// # Parameters
        /// * `transaction_id` - The ID of the transaction to be executed
        /// * `caller` - The contract address of the member executing the transaction
        ///
        /// # Panics
        /// It raises an error if the transaction with the given ID does not exist.
        /// It raises an error if the transaction is not executable (not approved).
        /// It raises an error if the caller is not a member of the account.
        /// It raises an error if the caller does not have the executor permission.
        /// It raises an error if the contract is paused.
        fn execute_transaction(ref self: ComponentState<TContractState>, transaction_id: u256,) {
            // PAUSE GUARD
            let pausable = get_dep_component!(@self, Pausable);
            pausable.assert_not_paused();

            // check if the transaction is valid and executable
            self.assert_valid_transaction(transaction_id);
            let transaction = self.transactions.entry(transaction_id);
            assert(
                transaction.tx_status.read() == TransactionStatus::APPROVED,
                Errors::ERR_TRANSACTION_NOT_EXECUTABLE
            );
            // Validate member (with smart will support)
            let (member, _caller) = self.validate_member(get_caller_address());

            let permission_control_comp = get_dep_component!(@self, PermissionControl);
            assert(
                permission_control_comp.has_permission(member, Permissions::EXECUTOR),
                Errors::ERR_NOT_EXECUTOR
            );

            transaction.tx_status.write(TransactionStatus::EXECUTED);
            let timestamp = get_block_timestamp();
            transaction.date_executed.write(timestamp);
            transaction.executor.write(member);

            // Increment executor's count
            self._increment_executed_count(member);

            // Collect Fee
            self.collect_fees(FeesType::EXECUTION_FEE);

            self
                .emit(
                    TransactionExecuted {
                        transaction_id: transaction_id, executor: member, date_executed: timestamp,
                    }
                );
        }
        /// Updates the status of a transaction
        /// This function updates the status of a transaction to the given status.
        ///
        /// # Parameters
        /// * `transaction_id` - The ID of the transaction to be updated
        /// * `status` - The new status of the transaction
        ///
        /// # Panics
        /// It raises an error if the transaction with the given ID does not exist.
        /// It raises an error if the transaction ID is zero.
        fn _update_transaction_status(
            ref self: ComponentState<TContractState>,
            transaction_id: u256,
            status: TransactionStatus
        ) {
            self.assert_valid_transaction(transaction_id);
            self.transactions.entry(transaction_id).tx_status.write(status);
        }
        /// Asserts that a transaction is valid
        /// This function checks if a transaction ID is valid, meaning it exists and is not zero.
        ///
        /// # Parameters
        /// * `transaction_id` - The ID of the transaction to be checked
        ///
        /// # Panics
        /// It raises an error if the transaction ID is not valid (greater than the current count or
        /// zero).
        /// It raises an error if the transaction ID is zero.
        fn assert_valid_transaction(self: @ComponentState<TContractState>, transaction_id: u256) {
            let tx_count = self.tx_count.read();
            assert(transaction_id <= tx_count, Errors::ERR_INVALID_TRANSACTION);
            assert(transaction_id != 0, Errors::ERR_INVALID_TRANSACTION);
        }
        /// Asserts that a transaction is votable
        /// This function checks if a transaction is in a votable state, meaning it has been
        /// initiated and is not yet executed, approved or rejected.
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
        /// Asserts that the caller can vote on a transaction
        /// This function checks if the caller is a member, has the voter permission, and has not
        /// already voted on the transaction.
        ///
        /// # Parameters
        /// * `transaction_id` - The ID of the transaction to be voted on
        /// * `caller` - The contract address of the caller
        ///
        /// # Panics
        /// It raises an error if the transaction is not valid.
        /// It raises an error if the transaction is not votable.
        /// It raises an error if the caller is not a member of the account.
        /// It raises an error if the caller does not have the voter permission.
        /// It raises an error if the caller has already voted on the transaction.
        fn assert_caller_can_vote(
            self: @ComponentState<TContractState>, transaction_id: u256, caller: ContractAddress
        ) {
            // check for transaction validity
            // check if transaction in range
            self.assert_valid_transaction(transaction_id);
            // check if transaction is votable
            self.assert_is_votable_transaction(transaction_id);

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
        fn _increment_proposed_count(
            ref self: ComponentState<TContractState>, member: ContractAddress
        ) {
            let current_count = self.member_proposed_count.entry(member).read();
            self.member_proposed_count.entry(member).write(current_count + 1);
        }
        fn _increment_approved_count(
            ref self: ComponentState<TContractState>, member: ContractAddress
        ) {
            let current_count = self.member_approved_count.entry(member).read();
            self.member_approved_count.entry(member).write(current_count + 1);
        }
        fn _increment_rejected_count(
            ref self: ComponentState<TContractState>, member: ContractAddress
        ) {
            let current_count = self.member_rejected_count.entry(member).read();
            self.member_rejected_count.entry(member).write(current_count + 1);
        }
        fn _increment_executed_count(
            ref self: ComponentState<TContractState>, member: ContractAddress
        ) {
            let current_count = self.member_executed_count.entry(member).read();
            self.member_executed_count.entry(member).write(current_count + 1);
        }
        fn validate_will_conditions(
            self: @ComponentState<TContractState>,
            member: ContractAddress,
            will_address: ContractAddress
        ) {
            // Check if will_address is zero
            assert(!will_address.is_zero(), Errors::ERR_INVALID_WILL_ADDRESS);

            // Check if will_address is not a member
            assert(!self.is_member(will_address), Errors::ERR_WILL_ADDRESS_IS_MEMBER);

            // Check if will_address is already assigned to another member
            let assigned_member = self.smart_will_to_member.entry(will_address).read();
            assert(assigned_member.is_zero(), Errors::ERR_WILL_ADDRESS_ALREADY_ASSIGNED);

            // Check if member can update their will
            let creation_time = self.member_will_creation_time.entry(member).read();
            if creation_time != 0 {
                let duration = self.member_to_will_duration.entry(member).read();
                let current_time = get_block_timestamp();
                assert(duration > current_time, Errors::ERR_WILL_DURATION_NOT_ELAPSED);
            }
        }
        fn collect_fees(ref self: ComponentState<TContractState>, fee_type: FeesType) {
            let account_address = get_contract_address();
            // Get the deployer address and dispatcher
            let deployer = IAccountDispatcher { contract_address: account_address }.get_deployer();
            let deployer_dispatcher = ISpherreDispatcher { contract_address: deployer };
            // Get Fees and Fees Token
            let fee = deployer_dispatcher.get_fee(fee_type, account_address);
            let fee_token = deployer_dispatcher.get_fee_token();

            // Stop execution if fee is equal to zero or fee token is zero
            if fee == 0 || fee_token.is_zero() {
                return;
            }

            // Collect the fees from the account
            // TODO: change fee collection from account to caller
            // Check if the caller balance is enough to pay fee
            let erc20_dispatcher = IERC20Dispatcher { contract_address: fee_token };
            let caller = get_caller_address();
            assert(erc20_dispatcher.balance_of(caller) >= fee, Errors::ERR_INSUFFICIENT_FEE);
            // Check that the allowance is enough for the fee
            assert(
                erc20_dispatcher.allowance(caller, account_address) >= fee,
                Errors::ERR_INSUFFICIENT_ALLOWANCE
            );
            // Transfer Fee
            erc20_dispatcher.transfer_from(account_address, deployer, fee);
            // Update the collection statistics
            deployer_dispatcher.update_fee_collection_statistics(fee_type, fee);
        }
        fn validate_member(
            self: @ComponentState<TContractState>, caller: ContractAddress
        ) -> (ContractAddress, ContractAddress) {
            // Validate that the caller is a member or is a smart will address of a member
            if self.is_member(caller) {
                // Caller is a member
                let will_address = self.get_member_will_address(caller);
                if will_address.is_zero() {
                    // No smart will, return (caller, caller)
                    (caller, caller)
                } else {
                    // Check if the will duration has elapsed
                    let remaining_time = self.get_remaining_will_time(caller);
                    assert(remaining_time > 0, Errors::AUTHORITY_DELEGATED_TO_WILL);
                    (caller, caller)
                }
            } else {
                // Caller is not a member
                // Check if the caller is a smart will address of a member
                let member = self.smart_will_to_member.entry(caller).read();
                assert(member.is_non_zero(), Errors::ERR_NOT_MEMBER);
                // Check that the member is a valid member
                assert(self.is_member(member), Errors::ERR_NOT_MEMBER);
                // Check if the will duration has elapsed
                let remaining_time = self.get_remaining_will_time(member);
                assert(remaining_time == 0, Errors::ERR_WILL_DURATION_NOT_ELAPSED);
                (member, caller)
            }
        }
    }
}
