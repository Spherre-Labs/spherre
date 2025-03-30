#[starknet::component]
pub mod PermissionControl {
    use core::pedersen::pedersen; // Import the pedersen function
    use spherre::interfaces::ipermission_control::IPermissionControl;
    use spherre::types::{Permissions, PermissionEnum}; // Import permission constants
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
    pub enum Event {
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

        /// Returns all the permissions the member has.
        /// @param member The address of the member (ContractAddress).
        fn get_member_permissions(
            self: @ComponentState<TContractState>, member: ContractAddress,
        ) -> Array<PermissionEnum> {
            let mut permisions: Array<PermissionEnum> = array![];

            if self.has_permission(member, Permissions::PROPOSER) {
                permisions.append(PermissionEnum::PROPOSER);
            }
            if self.has_permission(member, Permissions::EXECUTOR) {
                permisions.append(PermissionEnum::EXECUTOR);
            }
            if self.has_permission(member, Permissions::VOTER) {
                permisions.append(PermissionEnum::VOTER);
            }

            return permisions;
        }
    }
    /// Internal implementation.
    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        /// Assigns the PROPOSER permission to a member.
        /// Emits a PermissionGranted event.
        /// @param member The address of the member (ContractAddress).
        fn assign_proposer_permission(
            ref self: ComponentState<TContractState>, member: ContractAddress
        ) {
            let permissioned = self.has_permission(member, Permissions::PROPOSER);
            if (!permissioned) {
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
        }

        /// Assigns the VOTER permission to a member.
        /// Emits a PermissionGranted event.
        /// @param member The address of the member (ContractAddress).
        fn assign_voter_permission(
            ref self: ComponentState<TContractState>, member: ContractAddress
        ) {
            let permissioned = self.has_permission(member, Permissions::VOTER);
            if (!permissioned) {
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
        }

        /// Assigns the EXECUTOR permission to a member.
        /// Emits a PermissionGranted event.
        /// @param member The address of the member (ContractAddress).
        fn assign_executor_permission(
            ref self: ComponentState<TContractState>, member: ContractAddress
        ) {
            let permissioned = self.has_permission(member, Permissions::EXECUTOR);
            if (!permissioned) {
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
        fn revoke_proposer_permission(
            ref self: ComponentState<TContractState>, member: ContractAddress,
        ) {
            let permissioned = self.has_permission(member, Permissions::PROPOSER);
            if (permissioned) {
                self.revoke_permission(member, Permissions::PROPOSER);
            }
        }

        /// Revokes `voter permission` from `member`.
        ///
        /// If `member` has been granted `permission`, emits a `PermissionRevoked` event.
        ///
        /// Requirements:
        ///
        /// - The caller must have `role`'s admin role.
        fn revoke_voter_permission(
            ref self: ComponentState<TContractState>, member: ContractAddress,
        ) {
            let permissioned = self.has_permission(member, Permissions::VOTER);
            if (permissioned) {
                self.revoke_permission(member, Permissions::VOTER);
            }
        }

        /// Revokes `executor permission` from `member`.
        ///
        /// If `member` has been granted `permission`, emits a `PermissionRevoked` event.
        ///
        /// Requirements:
        ///
        /// - The caller must have `role`'s admin role.
        fn revoke_executor_permission(
            ref self: ComponentState<TContractState>, member: ContractAddress,
        ) {
            let permissioned = self.has_permission(member, Permissions::EXECUTOR);
            if (permissioned) {
                self.revoke_permission(member, Permissions::EXECUTOR);
            }
        }

        /// Assign all the permissions to the member.
        /// @param member The address of the member (ContractAddress).
        fn assign_all_permissions(
            ref self: ComponentState<TContractState>, member: ContractAddress
        ) {
            self.assign_proposer_permission(member);
            self.assign_voter_permission(member);
            self.assign_executor_permission(member);
        }

        /// Revokes all the permissions the member has.
        /// @param member The address of the member (ContractAddress).
        fn revoke_all_permissions(
            ref self: ComponentState<TContractState>, member: ContractAddress
        ) {
            self.revoke_proposer_permission(member);
            self.revoke_voter_permission(member);
            self.revoke_executor_permission(member);
        }
    }
}
