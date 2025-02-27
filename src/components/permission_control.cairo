#[starknet::component]
pub mod PermissionControl {
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{ContractAddress, get_caller_address};
    use crate::interfaces::ipermission_control;
    use openzeppelin::introspection::src5::SRC5Component::InternalImpl as SRC5InternalImpl;
    use openzeppelin::introspection::src5::SRC5Component;

    #[storage]
    pub struct Storage {
        /// Mapping of (permission type, member) to a boolean indicating if they have the permission.
        member_permission: Map<(felt252, ContractAddress), bool>,
        /// Mapping of (admin permission, admin) if they have the permission
        admin_permission: Map<felt252, felt252>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        PermissionRevoked: PermissionRevoked
    }

    #[derive(Drop, starknet::Event)]
    pub struct PermissionGranted {
        pub permission: felt252,
        pub member: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PermissionRevoked {
        pub permission: felt252,
        pub member: ContractAddress,
    }

    pub mod Errors {
        // pub const INVALID_CALLER: felt252 = 'Can only renounce role for self';
        pub const MISSING_ROLE: felt252 = 'Caller is missing role';
    }

    #[embeddable_as(AccessControlImpl)]
    impl AccessControl<
    TContractState, 
    +HasComponent<TContractState>,
    +SRC5Component::HasComponent<TContractState>,
    +Drop<TContractState>
    > of ipermission_control::IAccessControl<ComponentState<TContractState>>{
        /// Returns whether `account` has been granted `permission`.
        fn has_permission(
            self: @ComponentState<TContractState>, permission: felt252, member: ContractAddress,
        ) -> bool {
            self.member_permission.read((permission, member))
        }

        /// Returns the admin role that controls `role`.
        fn get_permission_admin(self: @ComponentState<TContractState>, role: felt252) -> felt252 {
            self.admin_permission.read(role)
        }

        /// Revokes `permission` from `member`.
        ///
        /// If `member` has been granted `permission`, emits a `PermissionRevoked` event.
        ///
        /// Requirements:
        ///
        /// - The caller must have `role`'s admin role.
        fn revoke_permission(
            ref self: ComponentState<TContractState>, permission: felt252, member: ContractAddress,
        ) {
            let admin = Self::get_permission_admin(@self, permission);
            self.assert_only_permission(admin);
            self._revoke_role(permission, member);
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Initializes the contract by registering the IAccessControl interface ID.
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(ipermission_control::IACCESSCONTROL_ID);
        }

        /// Validates that the caller has the given role. Otherwise it panics.
        fn assert_only_permission(self: @ComponentState<TContractState>, permission: felt252) {
            let caller: ContractAddress = get_caller_address();
            let authorized = AccessControl::has_permission(self, permission, caller);
            assert(authorized, Errors::MISSING_ROLE);
        }

        /// Attempts to revoke `permission` from `member`.
        ///
        /// Internal function without access restriction.
        ///
        /// May emit a `PermissionRevoked` event.
        fn _revoke_role(
            ref self: ComponentState<TContractState>, permission: felt252, member: ContractAddress,
        ) {
            if AccessControl::has_permission(@self, permission, member) {
                self.member_permission.write((permission, member), false);
                self.emit(PermissionRevoked { permission, member });
            }
        }
    }
}
