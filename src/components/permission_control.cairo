#[starknet::component]
pub mod PermissionControl {
    use core::pedersen::pedersen; // Import the pedersen function
    use spherre::interfaces::ipermission_control::IPermissionControl;
    use spherre::types::Permissions; // Import permission constants
    use starknet::ContractAddress;
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map
    };

    #[storage]
    pub struct Storage {
        member_permission: Map<
            (felt252, ContractAddress), bool
        >, // (Permission, Member) => bool (has_permission)
    }
    /// Events emitted by this component.
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        PermissionGranted: PermissionGranted,
        PermissionRevoked: PermissionRevoked,
    }
    /// Event emitted when a permission is granted.
    #[derive(Drop, starknet::Event)]
    pub struct PermissionGranted {
        pub permission: felt252,
        pub member: ContractAddress,
    }
    /// Event emitted when a permission is revoked.
    #[derive(Drop, starknet::Event)]
    pub struct PermissionRevoked {
        pub permission: felt252,
        pub account: ContractAddress,
    }

    /// Helper function to hash a tuple into a single felt252 using Pedersen hash.
    fn hash_key(permission: felt252, member: ContractAddress) -> felt252 {
        pedersen(permission, member.into())
    }
    /// External interface implementation.
    #[embeddable_as(PermissionControl)]
    impl PermissionControlImpl<
        TContractState, +HasComponent<TContractState>
    > of IPermissionControl<ComponentState<TContractState>> {
        /// Checks if the given member has the specified permission.
        /// @param member The address of the member (ContractAddress).
        /// @param permission The permission identifier (felt252).
        /// @return true if the member has the permission, false otherwise.
        fn has_permission(
            self: @ComponentState<TContractState>, member: ContractAddress, permission: felt252
        ) -> bool {
            self
                .member_permission
                .entry((permission, member))
                .read() // Read the value from storage.
        }
    }

    /// Internal implementation.
    #[generate_trait]
    impl PermissionControlInternalImpl<
        TContractState, +HasComponent<TContractState>
    > of PermissionControlInternalTrait<TContractState> {
        /// Assigns the PROPOSER permission to a member.
        /// Emits a PermissionGranted event.
        /// @param member The address of the member (ContractAddress).
        fn assign_proposer_permission(
            ref self: ComponentState<TContractState>, member: ContractAddress
        ) {
            self
                .member_permission
                .entry((Permissions::PROPOSER, member))
                .write(true); // Grant the permission.
            self
                .emit(
                    Event::PermissionGranted(
                        PermissionGranted { permission: Permissions::PROPOSER, member }
                    )
                ); // Emit the PermissionGranted event.
        }

        /// Assigns the VOTER permission to a member.
        /// Emits a PermissionGranted event.
        /// @param member The address of the member (ContractAddress).
        fn assign_voter_permission(
            ref self: ComponentState<TContractState>, member: ContractAddress
        ) {
            self
                .member_permission
                .entry((Permissions::VOTER, member))
                .write(true); // Grant the permission.
            self
                .emit(
                    Event::PermissionGranted(
                        PermissionGranted { permission: Permissions::VOTER, member }
                    )
                ); // Emit the PermissionGranted event.
        }

        /// Assigns the EXECUTOR permission to a member.
        /// Emits a PermissionGranted event.
        /// @param member The address of the member (ContractAddress).
        fn assign_executor_permission(
            ref self: ComponentState<TContractState>, member: ContractAddress
        ) {
            self
                .member_permission
                .entry((Permissions::EXECUTOR, member))
                .write(true); // Grant the permission.
            self
                .emit(
                    Event::PermissionGranted(
                        PermissionGranted { permission: Permissions::EXECUTOR, member }
                    )
                ); // Emit the PermissionGranted event.
        }

        /// Revokes a specific permission from a member.
        /// Emits a PermissionRevoked event.
        /// @param member The address of the member (ContractAddress).
        /// @param permission The permission identifier (felt252).
        fn revoke_permission(
            ref self: ComponentState<TContractState>, member: ContractAddress, permission: felt252
        ) {
            self
                .member_permission
                .entry((permission, member))
                .write(false); // Revoke the permission.
            self
                .emit(
                    Event::PermissionRevoked(PermissionRevoked { permission, account: member })
                ); // Emit the PermissionRevoked event.
        }

        /// Revokes `proposer permission` from `member`.
        ///
        /// If `member` has been granted `permission`, emits a `PermissionRevoked` event.
        ///
        /// Requirements:
        ///
        /// - The caller must have `role`'s admin role.
        fn _revoke_proposer_permission(
            ref self: ComponentState<TContractState>, permission: felt252, member: ContractAddress,
        ) {
            let permissioned = self.has_permission(PROPOSER, member);
            if (permissioned) {
                revoke_permission(member, permission);
            }
            Errors::MISSING_ROLE;
        }

        /// Revokes `voter permission` from `member`.
        ///
        /// If `member` has been granted `permission`, emits a `PermissionRevoked` event.
        ///
        /// Requirements:
        ///
        /// - The caller must have `role`'s admin role.
        fn _revoke_voter_permission(
            ref self: ComponentState<TContractState>, permission: felt252, member: ContractAddress,
        ) {
            let permissioned = self.has_permission(VOTER, member);
            if (permissioned) {
                revoke_permission(member, permission);
            }
            Errors::MISSING_ROLE;
        } 

        /// Revokes `executor permission` from `member`.
        ///
        /// If `member` has been granted `permission`, emits a `PermissionRevoked` event.
        ///
        /// Requirements:
        ///
        /// - The caller must have `role`'s admin role.
        fn _revoke_executor_permission(
            ref self: ComponentState<TContractState>, permission: felt252, member: ContractAddress,
        ) {
            let permissioned = self.has_permission(EXECUTOR, member);
            if (permissioned) {
                revoke_permission(member, permission);
            }
            Errors::MISSING_ROLE;
        }
    }
}