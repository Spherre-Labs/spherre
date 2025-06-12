use spherre::types::TokenTransactionData;
use starknet::ContractAddress;

/// Interface for the TokenTransaction component
/// This interface defines the entrypoints of the TokenTransaction component.
/// It includes methods for proposing, retrieving, and executing token transactions.

#[starknet::interface]
pub trait ITokenTransaction<TContractState> {
    /// Proposes a new token transaction
    /// This function allows a member with the proposer permission to propose a transaction
    /// involving a token, that is transferring a specified amount of tokens to another member.
    ///
    /// # Parameters
    /// * `token` - The contract address of the token contract.
    /// * `amount` - The amount of tokens to be transferred.
    /// * `recipient` - The contract address of the recipient member to whom the tokens will be
    /// transferred.
    ///
    /// # Panics
    /// This function raises an error if the caller does not have the proposer permission.
    /// This function raises an error if the recipient address is the zero address.
    /// This function raises an error if the token contract address is the zero address.
    /// This function raises an error if the amount is zero.
    /// This function raises an error if the account does not have enough tokens to transfer the
    /// specified amount.
    ///
    /// # Returns
    /// * `u256` The ID of the proposed token transaction.
    fn propose_token_transaction(
        ref self: TContractState, token: ContractAddress, amount: u256, recipient: ContractAddress
    ) -> u256;
    /// Retrieves a token transaction by its ID
    /// This function allows retrieval of a specific token transaction
    /// by its unique identifier.
    ///
    /// # Parameters
    /// * `id` - The ID of the token transaction to retrieve.
    ///
    /// # Panics
    /// This function raises an error if the transaction with the given ID does not exist.
    /// This function raises an error if the transaction is not a token transaction.
    ///
    /// # Returns
    /// * `TokenTransactionData` The details of the token transaction.
    fn get_token_transaction(self: @TContractState, id: u256) -> TokenTransactionData;
    /// Retrieves all token transactions
    /// This function returns a list of all token transactions that have been created.
    ///
    /// # Returns
    /// * `Array<TokenTransactionData>` An array of all token transactions.
    fn token_transaction_list(self: @TContractState) -> Array<TokenTransactionData>;
    /// Executes a token transaction
    /// This function allows a member with the executor permission to execute a token transaction.
    ///
    /// # Parameters
    /// * `id` - The ID of the token transaction to execute.
    ///
    /// # Panics
    /// This function raises an error if the transaction with the given ID does not exist.
    /// This function raises an error if the transaction is not a token transaction.
    /// This function raises an error if the caller does not have the executor permission.
    /// This function raises an error if the transaction is already executed.
    /// This function raises an error if the transaction is not approved.
    /// This function raises an error if the contract is paused.
    /// This function raises an error if the account does not have enough tokens to transfer the
    /// specified amount.
    fn execute_token_transaction(ref self: TContractState, id: u256);
}
