#[starknet::component]
pub mod MemberAddTransaction {
    use core::num::traits::Zero;
    use openzeppelin_security::PausableComponent::InternalImpl as PausableInternalImpl;
    use openzeppelin_security::pausable::PausableComponent;
    use spherre::account_data::AccountData::InternalImpl;
    use spherre::account_data::AccountData::InternalTrait;
    use spherre::account_data;
    use spherre::components::permission_control::PermissionControl::InternalImpl as PermissionControlInternalImpl;
    use spherre::components::permission_control;
    use spherre::errors::Errors;
    use spherre::interfaces::iaccount_data::IAccountData;

    use spherre::interfaces::imember_add_tx::IMemberAddTransaction;
    use spherre::interfaces::ipermission_control::IPermissionControl;
    use spherre::types::{MemberAddData, Transaction};
    use spherre::types::{PermissionEnum};
    use spherre::types::{TransactionType};
    use starknet::storage::{
        Map, StoragePathEntry, Vec, VecTrait, MutableVecTrait, StoragePointerReadAccess,
        StoragePointerWriteAccess
    };
    use starknet::{ContractAddress, get_contract_address, get_caller_address};

    #[storage]
    pub struct Storage {
        member_add_transactions: Map<u256, MemberAddData>,
        member_add_transaction_ids: Vec<u256>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        MemberAddTransactionProposed: MemberAddTransactionProposed,
        MemberAddTransactionExecuted: MemberAddTransactionExecuted,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MemberAddTransactionProposed {
        #[key]
        pub transaction_id: u256,
        pub member: ContractAddress,
        pub permissions: u8,
    }
    #[derive(Drop, starknet::Event)]
    pub struct MemberAddTransactionExecuted {
        #[key]
        pub transaction_id: u256,
        pub member: ContractAddress,
        pub permissions: u8,
    }

    #[embeddable_as(MemberAddTransaction)]
    pub impl MemberAddTransactionImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl AccountData: account_data::AccountData::HasComponent<TContractState>,
        impl PermissionControl: permission_control::PermissionControl::HasComponent<TContractState>,
        impl Pausable: PausableComponent::HasComponent<TContractState>,
    > of IMemberAddTransaction<ComponentState<TContractState>> {
        fn propose_member_add_transaction(
            ref self: ComponentState<TContractState>, member: ContractAddress, permissions: u8
        ) -> u256 {
            // validate that member is not zero
            assert(member.is_non_zero(), Errors::ERR_NON_ZERO_MEMBER_ADDRESS);
            let permission_control_comp = get_dep_component!(@self, PermissionControl);
            // Validate the provided permission
            assert(
                permission_control_comp.is_valid_mask(permissions),
                Errors::ERR_INVALID_PERMISSION_MASK
            );

            let mut account_data_comp = get_dep_component_mut!(ref self, AccountData);
            // Validate that member_address is not in members_list
            assert(!account_data_comp.is_member(member), Errors::ERR_ALREADY_A_MEMBER);
            // Create the transaction in account data and get the id
            let tx_id = account_data_comp.create_transaction(TransactionType::MEMBER_ADD);

            // Create member add transaction
            let member_add_transaction = MemberAddData { member, permissions };

            // Store the transaction
            self.member_add_transactions.entry(tx_id).write(member_add_transaction);

            self.member_add_transaction_ids.append().write(tx_id);

            // Emit event
            self.emit(MemberAddTransactionProposed { transaction_id: tx_id, member, permissions });

            tx_id
        }

        fn get_member_add_transaction(
            self: @ComponentState<TContractState>, transaction_id: u256
        ) -> MemberAddData {
            let account_data_comp = get_dep_component!(self, AccountData);
            let transaction: Transaction = account_data_comp.get_transaction(transaction_id);
            assert(
                transaction.tx_type == TransactionType::MEMBER_ADD,
                Errors::ERR_INVALID_MEMBER_ADD_TRANSACTION
            );
            self.member_add_transactions.entry(transaction_id).read()
        }

        fn member_add_transaction_list(
            self: @ComponentState<TContractState>
        ) -> Array<MemberAddData> {
            let mut array: Array<MemberAddData> = array![];
            let range_stop = self.member_add_transaction_ids.len();

            for index in 0
                ..range_stop {
                    let id = self.member_add_transaction_ids.at(index).read();
                    let tx = self.member_add_transactions.entry(id).read();
                    array.append(tx);
                };
            array
        }
        fn execute_member_add_transaction(
            ref self: ComponentState<TContractState>, transaction_id: u256
        ) {
            let caller = get_caller_address();
            let account_data_comp = get_dep_component_mut!(ref self, AccountData);
            let permission_control_comp = get_dep_component_mut!(ref self, PermissionControl);
            let member_add_data = self.get_member_add_transaction(transaction_id);
            assert(
                !account_data_comp.is_member(member_add_data.member), Errors::ERR_ALREADY_A_MEMBER
            );
            assert(
                permission_control_comp.is_valid_mask(member_add_data.permissions),
                Errors::ERR_INVALID_PERMISSION_MASK
            );
            // Execute the transaction (error occurs if threshold is not met or caller is not an
            // executor)
            account_data_comp.account_data_comp.execute_transaction(id, caller);

            // Convert mask to permissions
            let permissions = permission_control_comp
                .permissions_from_mask(member_add_data.permissions);

            // add the member
            account_data_comp.add_member(member_add_data.member);

            // Assign Permission
            permission_control.assign_permissions_from_enums(member_add_data.member, permissions);

            // emit event
            self
                .emit(
                    MemberAddTransactionExecuted {
                        transaction_id,
                        member: member_add_data.member,
                        permissions: member_add_data.permissions
                    }
                );
        }
    }
}
