//! This module implements the MemberPermissionTransaction component, which allows for proposing and
//! managing permission edit transactions for members in a Starknet-based application.
//! It includes methods for proposing, retrieving, and managing member permission edit transactions.
//!
//!
//! The comment documentation of the public entrypoints can be found in the interface
//! `IEditPermissionTransaction`.

#[starknet::component]
pub mod MemberPermissionTransaction {
    use core::num::traits::Zero;
    use openzeppelin::security::PausableComponent::InternalImpl as PausableInternalImpl;
    use openzeppelin::security::pausable::PausableComponent;
    use spherre::account_data::AccountData::AccountDataImpl;
    use spherre::account_data::AccountData::InternalTrait as AccountDataInternalTrait;
    use spherre::account_data::AccountData::{InternalImpl as AccountDataInternalImpl};
    use spherre::account_data;
    use spherre::components::permission_control::PermissionControl::InternalImpl as PermissionControlInternalImpl;
    use spherre::components::permission_control;
    use spherre::errors::Errors;
    use spherre::interfaces::iaccount_data::IAccountData;
    use spherre::interfaces::iedit_permission_tx::IEditPermissionTransaction;
    use spherre::interfaces::ipermission_control::IPermissionControl;
    use spherre::types::{EditPermissionTransaction, TransactionType};
    use starknet::storage::{
        Map, StoragePathEntry, Vec, VecTrait, MutableVecTrait, StoragePointerReadAccess,
        StoragePointerWriteAccess
    };
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    pub struct Storage {
        member_permission_transactions: Map<u256, EditPermissionTransaction>,
        member_permission_transaction_ids: Vec<u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        PermissionEditProposed: PermissionEditProposed,
        PermissionEditExecuted: PermissionEditExecuted,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PermissionEditProposed {
        #[key]
        pub transaction_id: u256,
        pub member: ContractAddress,
        pub new_permissions: u8
    }

    #[derive(Drop, starknet::Event)]
    pub struct PermissionEditExecuted {
        #[key]
        pub transaction_id: u256,
        pub member: ContractAddress,
        pub new_permissions: u8
    }


    #[embeddable_as(MemberPermissionTransaction)]
    pub impl MemberPermissionTransactionImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl AccountData: account_data::AccountData::HasComponent<TContractState>,
        impl PermissionControl: permission_control::PermissionControl::HasComponent<TContractState>,
        impl Pausable: PausableComponent::HasComponent<TContractState>,
    > of IEditPermissionTransaction<ComponentState<TContractState>> {
        fn propose_edit_permission_transaction(
            ref self: ComponentState<TContractState>, member: ContractAddress, new_permissions: u8
        ) -> u256 {
            // Pause guard
            let pausable = get_dep_component!(@self, Pausable);
            pausable.assert_not_paused();

            // Validate inputs
            assert(!member.is_zero(), Errors::ERR_ZERO_MEMBER_ADDRESS);

            // Check if permission mask is valid
            let permission_control = get_dep_component!(@self, PermissionControl);
            assert(
                permission_control.is_valid_mask(new_permissions),
                Errors::ERR_INVALID_PERMISSION_MASK
            );

            // Check if member exists
            let account_data = get_dep_component!(@self, AccountData);
            assert(account_data.is_member(member), Errors::MEMBER_NOT_FOUND);

            // Check if new permissions differ from current
            let current_permissions = permission_control.get_member_permissions(member);
            let current_mask = permission_control.permissions_to_mask(current_permissions);
            assert(new_permissions != current_mask, Errors::ERR_SAME_PERMISSIONS);

            // Create transaction
            let transaction = EditPermissionTransaction { member, new_permissions };

            // Create transaction and get ID
            let mut account_data_internal = get_dep_component_mut!(ref self, AccountData);
            let tx_id = account_data_internal
                .create_transaction(TransactionType::MEMBER_PERMISSION_EDIT);
            self.member_permission_transaction_ids.append().write(tx_id);
            self.member_permission_transactions.entry(tx_id).write(transaction);

            // Emit event
            self.emit(PermissionEditProposed { transaction_id: tx_id, member, new_permissions });

            tx_id
        }

        fn get_edit_permission_transaction(
            self: @ComponentState<TContractState>, transaction_id: u256
        ) -> EditPermissionTransaction {
            let account_data_comp = get_dep_component!(self, AccountData);
            let transaction = account_data_comp.get_transaction(transaction_id);
            assert(
                transaction.tx_type == TransactionType::MEMBER_PERMISSION_EDIT,
                Errors::ERR_INVALID_MEMBER_PERMISSION_TRANSACTION
            );
            self.member_permission_transactions.entry(transaction_id).read()
        }

        fn get_edit_permission_transaction_list(
            self: @ComponentState<TContractState>
        ) -> Array<EditPermissionTransaction> {
            let mut array: Array<EditPermissionTransaction> = array![];
            let range_stop = self.member_permission_transaction_ids.len();

            for index in 0
                ..range_stop {
                    let id = self.member_permission_transaction_ids.at(index).read();
                    let tx = self.member_permission_transactions.entry(id).read();
                    array.append(tx);
                };
            array
        }

        fn execute_edit_permission_transaction(
            ref self: ComponentState<TContractState>, transaction_id: u256
        ) {
            // Get the transaction data
            let edit_permission_data = self.get_edit_permission_transaction(transaction_id);
            let member = edit_permission_data.member;
            let new_permissions = edit_permission_data.new_permissions;

            // check if member address is still a member
            let mut account_data_comp = get_dep_component_mut!(ref self, AccountData);
            assert(account_data_comp.is_member(member), Errors::MEMBER_NOT_FOUND);

            // Execute the transaction in account data
            account_data_comp.execute_transaction(transaction_id, get_caller_address());

            // Get the permission control component
            let mut permission_control_comp = get_dep_component_mut!(ref self, PermissionControl);

            // Convert mask to permissions
            let permissions = permission_control_comp.permissions_from_mask(new_permissions);

            // Assign Permission
            permission_control_comp.assign_permissions_from_enums(member, permissions);

            self.emit(PermissionEditExecuted { transaction_id, member, new_permissions });
        }
    }
}
