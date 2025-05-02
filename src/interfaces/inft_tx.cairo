
use spherre::types::NFTTransactionData;
use starknet::ContractAddress;

#[starknet::interface]
pub trait INFTTransaction<TContractState> {
    fn propose_nft_transaction(
        ref self: TContractState,
        nft_contract: ContractAddress,
        token_id: u256,
        recipient: ContractAddress
    ) -> u256;
    fn get_nft_transaction(self: @TContractState, id: u256) -> NFTTransactionData;
    fn nft_transaction_list(self: @TContractState) -> Array<NFTTransactionData>;
}