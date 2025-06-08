#[starknet::component]
pub mod MemberPermissionTransaction {
    use starknet::storage::{
        Map, StoragePathEntry, Vec, VecTrait, MutableVecTrait, StoragePointerReadAccess,
        StoragePointerWriteAccess, StorageMapWriteAccess, StorageMapReadAccess
    };
    use openzeppelin_security::PausableComponent::InternalImpl as PausableInternalImpl;
    use openzeppelin_security::pausable::PausableComponent;
    use spherre::account_data::AccountData::InternalImpl;
    use spherre::account_data;
    use spherre::components::permission_control::PermissionControl::InternalImpl as PermissionControlInternalImpl;
    use spherre::components::permission_control;
    use spherre::types::EditPermissionTransaction;
    use spherre::errors::Errors;
    use spherre::interfaces::iaccount_data::IAccountData;
    use spherre::interfaces::ipermission_control::IPermissionControl;
    use spherre::interfaces::imember_permission_tx::IMemberPermissionTransaction;
    use starknet::ContractAddress;
    use core::num::traits::Zero;

    #[storage]
    pub struct Storage {
        member_permission_transactions: Map<u256, EditPermissionTransaction>,
        member_permission_transaction_ids: Vec<u256>,
        member_permission_transaction_ids_len: u256,
        member_permission_tx_count: u256
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        PermissionEditProposed: PermissionEditProposed,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PermissionEditProposed {
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
    > of IMemberPermissionTransaction<ComponentState<TContractState>> {
        fn propose_member_permission_transaction(ref self: ComponentState<TContractState>, member: ContractAddress, new_permissions: u8) -> u256 {
            // Pause guard
            let pausable = get_dep_component!(@self, Pausable);
            pausable.assert_not_paused();

            // Validate inputs
            assert(member.is_non_zero(), Errors::ERR_NON_ZERO_MEMBER_ADDRESS);

            // Check if permission mask is valid
            let permission_control = get_dep_component!(@self, PermissionControl);
            assert(permission_control.is_valid_mask(new_permissions), Errors::ERR_INVALID_PERMISSION_MASK);

            // Convert mask to permissions for validation
            let new_permission_list = permission_control.permissions_from_mask(new_permissions);
            assert(new_permission_list.len() > 0, Errors::ERR_INVALID_PERMISSION_MASK);

            // Check if member exists
            let account_data = get_dep_component!(@self, AccountData);
            assert(account_data.is_member(member), Errors::MEMBER_NOT_FOUND);

            // Check if new permissions differ from current
            let current_permissions = permission_control.get_member_permissions(member);
            let current_mask = permission_control.permissions_to_mask(current_permissions);
            assert(new_permissions != current_mask, Errors::ERR_INVALID_PERMISSION_MASK);

            // Create transaction
            let transaction = EditPermissionTransaction { member, new_permissions };

            // Store transaction and update IDs
            let tx_id = self.member_permission_tx_count.read();
            self.member_permission_transactions.write(tx_id, transaction);
            let len = self.member_permission_transaction_ids_len.read();
            self.member_permission_transaction_ids.push(tx_id);
            self.member_permission_transaction_ids_len.write(len + 1);
            self.member_permission_tx_count.write(tx_id + 1);

            // Emit event
            self.emit(PermissionEditProposed { transaction_id: tx_id, member, new_permissions });

            tx_id
        }

        fn get_member_permission_transaction(self: @ComponentState<TContractState>, transaction_id: u256) -> (ContractAddress, u8) {
            let max_id = self.member_permission_tx_count.read();
            assert(transaction_id < max_id, Errors::TRANSACTION_NOT_FOUND);

            let transaction = self.member_permission_transactions.read(transaction_id);
            (transaction.member, transaction.new_permissions)
        }
    }
}