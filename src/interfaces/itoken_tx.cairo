use spherre::types::TokenTransactionData;
use starknet::ContractAddress;

#[starknet::interface]
pub trait ITokenTransaction<TContractState> {
    fn propose_token_transaction(
        ref self: TContractState, token: ContractAddress, amount: u256, recipient: ContractAddress
    ) -> u256;
    fn get_token_transaction(self: @TContractState, id: u256) -> TokenTransactionData;
    fn token_transaction_list(self: @TContractState) -> Array<TokenTransactionData>;
}
