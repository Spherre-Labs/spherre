//! This module implements a permission control system for managing member permissions in the
//! SpherreAccount contract. It allows for assigning and revoking permissions such as PROPOSER,
//! VOTER, and EXECUTOR to members of the contract. The permissions are stored in a mapping that
//! associates each member with their respective permissions. The component emits events when
//! permissions are granted or revoked, allowing for tracking of permission changes.
//! Also the component provides utilities for handling permissions as bit masks,
//! enabling efficient storage and manipulation of multiple permissions at once.

#[starknet::component]
pub mod PermissionControl {
    use core::pedersen::pedersen; // Import the pedersen function
    use spherre::interfaces::ipermission_control::IPermissionControl;
    use spherre::types::{
        PermissionEnum, PermissionTrait, Permissions,
    }; // Import permission constants
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };

    #[storage]
    pub struct Storage {
        member_permission: Map<
            (felt252, ContractAddress), bool,
        > // (Permission, Member) => bool (has_permission)
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
        TContractState, +HasComponent<TContractState>,
    > of IPermissionControl<ComponentState<TContractState>> {
        fn has_permission(
            self: @ComponentState<TContractState>, member: ContractAddress, permission: felt252,
        ) -> bool {
            self
                .member_permission
                .entry((permission, member))
                .read() // Read the value from storage.
        }
        fn get_member_permissions(
            self: @ComponentState<TContractState>, member: ContractAddress,
        ) -> Array<PermissionEnum> {
            let mut permissions: Array<PermissionEnum> = array![];

            if self.has_permission(member, Permissions::PROPOSER) {
                permissions.append(PermissionEnum::PROPOSER);
            }
            if self.has_permission(member, Permissions::EXECUTOR) {
                permissions.append(PermissionEnum::EXECUTOR);
            }
            if self.has_permission(member, Permissions::VOTER) {
                permissions.append(PermissionEnum::VOTER);
            }

            return permissions;
        }
        fn permissions_to_mask(
            self: @ComponentState<TContractState>, permissions: Array<PermissionEnum>,
        ) -> u8 {
            let mut mask: u8 = 0;
            for index in 0..permissions.len() {
                mask = mask | (*permissions.at(index)).to_mask();
            };
            mask
        }
        fn permissions_from_mask(
            self: @ComponentState<TContractState>, mask: u8,
        ) -> Array<PermissionEnum> {
            let mut permissions_array: Array<PermissionEnum> = array![];
            if PermissionEnum::PROPOSER.has_permission_from_mask(mask) {
                permissions_array.append(PermissionEnum::PROPOSER);
            }
            if PermissionEnum::VOTER.has_permission_from_mask(mask) {
                permissions_array.append(PermissionEnum::VOTER);
            }
            if PermissionEnum::EXECUTOR.has_permission_from_mask(mask) {
                permissions_array.append(PermissionEnum::EXECUTOR);
            }
            permissions_array
        }
        fn is_valid_mask(self: @ComponentState<TContractState>, mask: u8) -> bool {
            (PermissionEnum::PROPOSER.has_permission_from_mask(mask)
                || PermissionEnum::VOTER.has_permission_from_mask(mask)
                || PermissionEnum::EXECUTOR.has_permission_from_mask(mask))
        }
    }
    /// Internal implementation.
    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        /// Assigns the PROPOSER permission to a member.
        /// Emits a PermissionGranted event.
        ///
        /// # Parameters
        /// * `member` - The address of the member (ContractAddress).
        fn assign_proposer_permission(
            ref self: ComponentState<TContractState>, member: ContractAddress,
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
                            PermissionGranted { permission: Permissions::PROPOSER, member },
                        ),
                    ); // Emit the PermissionGranted event.
            }
        }

        /// Assigns the VOTER permission to a member.
        /// Emits a PermissionGranted event.
        ///
        /// # Parameters
        /// * `member` - The address of the member (ContractAddress).
        fn assign_voter_permission(
            ref self: ComponentState<TContractState>, member: ContractAddress,
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
                            PermissionGranted { permission: Permissions::VOTER, member },
                        ),
                    ); // Emit the PermissionGranted event.
            }
        }

        /// Assigns the EXECUTOR permission to a member.
        /// Emits a PermissionGranted event.
        ///
        /// # Parameters
        /// * `member` - The address of the member (ContractAddress).
        fn assign_executor_permission(
            ref self: ComponentState<TContractState>, member: ContractAddress,
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
                            PermissionGranted { permission: Permissions::EXECUTOR, member },
                        ),
                    ); // Emit the PermissionGranted event.
            }
        }

        /// Revokes a specific permission from a member.
        /// Emits a PermissionRevoked event.
        ///
        /// # Parameters
        /// - `member` - The address of the member (ContractAddress).
        /// - `permission` - The permission identifier (felt252).
        fn revoke_permission(
            ref self: ComponentState<TContractState>, member: ContractAddress, permission: felt252,
        ) {
            self
                .member_permission
                .entry((permission, member))
                .write(false); // Revoke the permission.
            self
                .emit(
                    Event::PermissionRevoked(PermissionRevoked { permission, account: member }),
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
        /// # Parameters
        /// - `member` - The address of the member (ContractAddress).
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
        /// # Parameters
        /// - `member` - The address of the member (ContractAddress).
        fn revoke_executor_permission(
            ref self: ComponentState<TContractState>, member: ContractAddress,
        ) {
            let permissioned = self.has_permission(member, Permissions::EXECUTOR);
            if (permissioned) {
                self.revoke_permission(member, Permissions::EXECUTOR);
            }
        }

        /// This function grants all permissions (PROPOSER, VOTER, EXECUTOR) to the specified
        /// member.
        /// Emits a PermissionGranted event for each permission granted.
        ///
        /// # Parameters
        /// - `member` - The address of the member (ContractAddress).
        fn assign_all_permissions(
            ref self: ComponentState<TContractState>, member: ContractAddress,
        ) {
            self.assign_proposer_permission(member);
            self.assign_voter_permission(member);
            self.assign_executor_permission(member);
        }

        /// This function revokes all permissions (PROPOSER, VOTER, EXECUTOR) from the specified
        /// member.
        /// Emits a PermissionRevoked event for each permission revoked.
        ///
        /// # Parameters
        /// - `member` - The address of the member (ContractAddress).
        fn revoke_all_permissions(
            ref self: ComponentState<TContractState>, member: ContractAddress,
        ) {
            self.revoke_proposer_permission(member);
            self.revoke_voter_permission(member);
            self.revoke_executor_permission(member);
        }
        /// Assigns permissions to a member based on an array of PermissionEnum.
        /// This function iterates through the provided permissions and assigns each one to the
        /// member.
        ///
        /// # Parameters
        /// - `member` - The address of the member (ContractAddress).
        /// - `permissions` - An array of PermissionEnum representing the permissions to be
        /// assigned.
        fn assign_permissions_from_enums(
            ref self: ComponentState<TContractState>,
            member: ContractAddress,
            permissions: Array<PermissionEnum>,
        ) {
            for index in 0..permissions.len() {
                match *permissions.at(index) {
                    PermissionEnum::PROPOSER => self.assign_proposer_permission(member),
                    PermissionEnum::VOTER => self.assign_voter_permission(member),
                    PermissionEnum::EXECUTOR => self.assign_executor_permission(member),
                }
            };
        }
    }
}
