use spherre::types::NFTTransactionData;
use starknet::ContractAddress;

/// Interface for the NFTTransaction component
/// This interface defines the entrypoints of the NFTTransaction component.
/// It includes methods for proposing, retrieving, and executing NFT transactions.

#[starknet::interface]
pub trait INFTTransaction<TContractState> {
    /// Proposes a new NFT transaction
    /// This function allows a member with the proposer permission to propose a transaction
    /// involving an NFT, that is transferring ownership of an NFT to another member.
    ///
    /// # Parameters
    /// * `nft_contract` - The contract address of the NFT contract.
    /// * `token_id` - The ID of the NFT token to be transferred.
    /// * `recipient` - The contract address of the recipient member to whom the NFT will be
    /// transferred.
    ///
    /// # Panics
    /// This function raises an error if the caller does not have the proposer permission.
    /// This function raises an error if the recipient address is the zero address.
    /// This function raises an error if the NFT contract address is the zero address.
    /// This function raises an error if the token ID is zero.
    /// This function raises an error if the account does not have the NFT with the specified token
    /// ID.
    ///
    /// # Returns
    /// * `u256` The ID of the proposed NFT transaction.
    fn propose_nft_transaction(
        ref self: TContractState,
        nft_contract: ContractAddress,
        token_id: u256,
        recipient: ContractAddress
    ) -> u256;
    /// Retrieves an NFT transaction by its ID
    /// This function allows retrieval of a specific NFT transaction
    /// by its unique identifier.
    ///
    /// # Parameters
    /// * `id` - The ID of the NFT transaction to retrieve.
    ///
    /// # Panics
    /// This function raises an error if the transaction with the given ID does not exist.
    /// This function raises an error if the transaction is not an NFT transaction.
    ///
    /// # Returns
    /// * `NFTTransactionData` The details of the NFT transaction.
    fn get_nft_transaction(self: @TContractState, id: u256) -> NFTTransactionData;
    /// Retrieves all NFT transactions
    /// This function returns a list of all NFT transactions that have been created.
    ///
    /// # Returns
    /// * `Array<NFTTransactionData>` An array of all NFT transactions.
    fn nft_transaction_list(self: @TContractState) -> Array<NFTTransactionData>;
    /// Executes an NFT transaction
    /// This function allows a member with the executor permission to execute an NFT transaction.
    ///
    /// # Parameters
    /// * `id` - The ID of the NFT transaction to execute.
    ///
    /// # Panics
    /// This function raises an error if the transaction with the given ID does not exist.
    /// This function raises an error if the transaction is not an NFT transaction.
    /// This function raises an error if the caller does not have the executor permission.
    /// This function raises an error if the transaction is already executed.
    /// This function raises an error if the transaction is not approved.
    /// This function raises an error if the contract is paused.
    /// This function raises an error if the account does not have the NFT with the specified token
    /// ID.
    fn execute_nft_transaction(ref self: TContractState, id: u256);
}
