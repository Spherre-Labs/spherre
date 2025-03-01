use starknet::ContractAddress;
#[starknet::interface]
pub trait IPermissionControl<TContractState> {
    fn has_permission(self: @TContractState, member:ContractAddress, permission: felt252) -> bool;
}