use starknet::ContractAddress;
#[starknet::interface]
pub trait IPermissionControl<TContractState> {
    /// Checks if a member has a specific permission.
    /// @param member The address of the member (ContractAddress).
    /// @param permission The permission identifier (felt252).
    /// @return true if the member has the permission, false otherwise.
    fn has_permission(self: @TContractState, member: ContractAddress, permission: felt252) -> bool;
}