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
}
