#[starknet::component]
pub mod MemberRemoveTransaction {
    use openzeppelin_security::PausableComponent::InternalImpl as PausableInternalImpl;
    use openzeppelin_security::pausable::PausableComponent;
    use spherre::account_data::AccountData::InternalImpl as AccountDataInternalImpl;
    use spherre::account_data;
    use spherre::components::permission_control;
    use spherre::components::permission_control::PermissionControl::InternalImpl as PermissionControlInternalImpl;
    use spherre::errors::Errors;
    use spherre::interfaces::iaccount_data::IAccountData;
    use spherre::interfaces::imember_remove_tx::IMemberRemoveTransaction;
    use spherre::interfaces::ipermission_control::IPermissionControl;
    use spherre::types::MemberRemoveData;
    use spherre::types::TransactionType;
    use spherre::types::{Transaction, Permissions};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry, Vec, VecTrait,
        MutableVecTrait
    };
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    pub struct Storage {
        member_removal_transactions: Map<u256, MemberRemoveData>,
        member_transaction_ids: Vec<u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        MemberRemovalProposed: MemberRemovalProposed,
        MemberRemovalExecuted: MemberRemovalExecuted,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MemberRemovalProposed {
        #[key]
        pub transaction_id: u256,
        #[key]
        pub member: ContractAddress
    }
    #[derive(Drop, starknet::Event)]
    pub struct MemberRemovalExecuted {
        #[key]
        pub transaction_id: u256,
        #[key]
        pub member: ContractAddress
    }


    #[embeddable_as(MemberRemoveTransaction)]
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
            // Get the component states
            let mut account_data_comp = get_dep_component_mut!(ref self, AccountData);

            // Validate that member can be removed
            self.assert_can_remove_member(member_address);
            
            // Create transaction through AccountData component
            let transaction_id = account_data_comp
                .create_transaction(TransactionType::MEMBER_REMOVE);

            // Create the member removal transaction
            let member_removal_transaction = MemberRemoveData { member_address, };

            // Store the transaction
            self
                .member_removal_transactions
                .entry(transaction_id)
                .write(member_removal_transaction);

            self.member_transaction_ids.append().write(transaction_id);

            // Emit event
            self
                .emit(
                    MemberRemovalProposed {
                        transaction_id,
                        member: member_address
                    }
                );

            transaction_id
        }

        fn get_member_removal_transaction(
            self: @ComponentState<TContractState>, transaction_id: u256
        ) -> MemberRemoveData {
            let account_data_comp = get_dep_component!(self, AccountData);
            let transaction: Transaction = account_data_comp.get_transaction(transaction_id);

            assert(
                transaction.tx_type == TransactionType::MEMBER_REMOVE,
                Errors::INVALID_MEMBER_REMOVE_TRANSACTION
            );

            self.member_removal_transactions.entry(transaction_id).read()
        }

        fn member_removal_transaction_list(
            self: @ComponentState<TContractState>
        ) -> Array<MemberRemoveData> {
            let mut array: Array<MemberRemoveData> = array![];
            let range_stop = self.member_transaction_ids.len();

            for index in 0
                ..range_stop {
                    let id = self.member_transaction_ids.at(index).read();
                    let tx = self.member_removal_transactions.entry(id).read();
                    array.append(tx);
                };
            array
        }
        fn execute_remove_member_transaction(
            ref self: ComponentState<TContractState>, transaction_id: u256
        ) {
            // Get the transaction (error is thrown if it does not exist or is not a member removal)
            let member_removal_data = self.get_member_removal_transaction(transaction_id);

            // Get the account data component
            let mut account_data_comp = get_dep_component_mut!(ref self, AccountData);

            // Validate that member can be removed
            self.assert_can_remove_member(member_removal_data.member_address);

            // Execute the transaction (error is thrown if caller is not an executor
            // or if transaction is already executed or if transaction is not approved or if contract is paused)
            let caller = get_caller_address();
            account_data_comp.execute_transaction(
                transaction_id,
                caller
            );

            // Remove the member from the account data component
            account_data_comp.remove_member(member_removal_data.member_address);
            // Remove all permissions that the member has
            let mut permission_control_comp = get_dep_component_mut!(ref self, PermissionControl);
            permission_control_comp.revoke_all_permissions(member_removal_data.member_address);
            // Emit event for member removal
            self.emit(
                MemberRemovalExecuted {
                    transaction_id,
                    member: member_removal_data.member_address,
                }
            );
        }
    }
     #[generate_trait]
    pub impl PrivateImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl AccountData: account_data::AccountData::HasComponent<TContractState>,
        impl PermissionControl: permission_control::PermissionControl::HasComponent<TContractState>,
        impl Pausable: PausableComponent::HasComponent<TContractState>,
    > of PrivateTrait<TContractState> {
        fn assert_can_remove_member(self: @ComponentState<TContractState>, member: ContractAddress) {
            let account_data_comp = get_dep_component!(self, AccountData);
            assert(account_data_comp.is_member(member), Errors::ERR_NOT_MEMBER);

            // Validate that removing the member does not affect the threshold
            
            let permission_control_comp = get_dep_component!(self, PermissionControl);
            let is_voter = permission_control_comp
                .has_permission(member, Permissions::VOTER);
            let voters_count = account_data_comp.get_number_of_voters();
            // check if the member is not the last voter
            assert(
                voters_count > 1 || !is_voter,
                Errors::ERR_CANNOT_REMOVE_LAST_VOTER
            );
            // Validate that the member is not the last proposer
            let is_proposer = permission_control_comp
                .has_permission(member, Permissions::PROPOSER);
            let proposers_count = account_data_comp.get_number_of_proposers();
            // check if the member is not the last proposer
            assert(
                proposers_count > 1 || !is_proposer,
                Errors::ERR_CANNOT_REMOVE_LAST_PROPOSER
            );
            // Validate that the member is not the last executor
            let is_executor = permission_control_comp
                .has_permission(member, Permissions::EXECUTOR);
            let executors_count = account_data_comp.get_number_of_executors();
            // check if the member is not the last executor
            assert(
                executors_count > 1 || !is_executor,
                Errors::ERR_CANNOT_REMOVE_LAST_EXECUTOR
            );
            // validate that the threshold is not equal to current number of voters and the member is not a voter
            let (threshold, _) = account_data_comp.get_threshold();
            assert(
                threshold < voters_count || !is_voter,
                Errors::ERR_CANNOT_REMOVE_MEMBER_WITH_THRESHOLD
            );
        }
    }
}
