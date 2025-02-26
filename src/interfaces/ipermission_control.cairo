#[starknet::interface]
use starknet::ContractAddress;
pub trait IPermissionControl<TContractState> {
    fn has_permission(
        self: @TContractState,
        member: ContractAddress,
        permission: felt252
    ) -> bool;
    
    fn assign_proposer_permission(ref self: TContractState, member: ContractAddress);
    fn assign_voter_permission(ref self: TContractState, member: ContractAddress);
    fn assign_executor_permission(ref self: TContractState, member: ContractAddress);
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
}