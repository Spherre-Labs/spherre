use starknet::ContractAddress;

#[starknet::interface]
pub trait ISpherre<TContractState> {
    // Ownable functions
    fn owner(self: @TContractState) -> ContractAddress;
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn renounce_ownership(ref self: TContractState);

    // Pausable functions
    fn is_paused(self: @TContractState) -> bool;
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);

    // ReentrancyGuard functions
    fn reentrancy_guard_start(ref self: TContractState);
    fn reentrancy_guard_end(ref self: TContractState);

    // AccessControl functions
    fn has_role(self: @TContractState, role: felt252, account: ContractAddress) -> bool;
    fn get_role_admin(self: @TContractState, role: felt252) -> felt252;
    fn grant_role(ref self: TContractState, role: felt252, account: ContractAddress);
    fn revoke_role(ref self: TContractState, role: felt252, account: ContractAddress);
    fn renounce_role(ref self: TContractState, role: felt252, account: ContractAddress);

    // SRC5 functions
    fn supports_interface(self: @TContractState, interface_id: felt252) -> bool;
}
