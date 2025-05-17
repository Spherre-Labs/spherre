use spherre::types::PermissionEnum;
use starknet::ContractAddress;
#[starknet::interface]
pub trait IPermissionControl<TContractState> {
    /// Checks if a member has a specific permission.
    /// @param member The address of the member (ContractAddress).
    /// @param permission The permission identifier (felt252).
    /// @return true if the member has the permission, false otherwise.
    fn has_permission(self: @TContractState, member: ContractAddress, permission: felt252) -> bool;
    /// Returns all permissions held by a member.
    /// @param member The address of the member (ContractAddress).
    fn get_member_permissions(
        self: @TContractState, member: ContractAddress,
    ) -> Array<PermissionEnum>;
    /// Returns a mask representing the permissions.
    /// @param The Array of permissions.
    fn permissions_to_mask(self: @TContractState, permissions: Array<PermissionEnum>) -> u8;
    /// Returns the permissions from a mask.
    /// @param The mask.
    fn permissions_from_mask(self: @TContractState, mask: u8) -> Array<PermissionEnum>;
    /// Check whether the mask is a valid permission mask
    /// Returns true if valid
    /// @param The mask
    fn is_valid_mask(self: @TContractState, mask: u8) -> bool;
}
