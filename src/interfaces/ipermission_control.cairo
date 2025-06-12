use spherre::types::PermissionEnum;
use starknet::ContractAddress;

/// Interface for the PermissionControl component
/// This interface defines the entrypoints of the PermissionControl component.
/// It includes methods for checking permissions, retrieving member permissions

#[starknet::interface]
pub trait IPermissionControl<TContractState> {
    /// Checks if a member has a specific permission.
    ///
    /// # Parameters
    /// * `member` - The address of the member (ContractAddress).
    /// * `permission` - The permission to check (felt252).
    ///
    /// # Returns
    /// * `bool` - Returns true if the member has the specified permission, false otherwise.
    fn has_permission(self: @TContractState, member: ContractAddress, permission: felt252) -> bool;
    /// Returns all permissions held by a member.
    ///
    /// # Parameters
    /// * `member` - The address of the member (ContractAddress).
    ///
    /// # Returns
    /// * `Array<PermissionEnum>` - An array of permissions held by the member.
    fn get_member_permissions(
        self: @TContractState, member: ContractAddress,
    ) -> Array<PermissionEnum>;
    /// Returns a mask representing the permissions.
    ///
    /// # Parameters
    /// * `permissions` - An array of permissions (Array<PermissionEnum>).
    ///
    /// # Returns
    /// * `u8` - A mask representing the permissions.
    fn permissions_to_mask(self: @TContractState, permissions: Array<PermissionEnum>) -> u8;
    /// Returns the permissions from a mask.
    ///
    /// # Parameters
    /// * `mask` - A mask representing the permissions (u8).
    ///
    /// # Returns
    /// * `Array<PermissionEnum>` - An array of permissions derived from the mask.
    fn permissions_from_mask(self: @TContractState, mask: u8) -> Array<PermissionEnum>;
    /// Check whether the mask is a valid permission mask
    ///
    /// # Parameters
    /// * `mask` - The mask to check (u8).
    ///
    /// # Returns
    /// * `bool` - Returns true if the mask is valid, false otherwise.
    fn is_valid_mask(self: @TContractState, mask: u8) -> bool;
}
