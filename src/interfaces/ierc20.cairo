use starknet::ContractAddress;

/// Interface for the ERC20 token standard
/// This interface defines the entrypoints of the ERC20 token contract.
/// It includes methods for retrieving token details, managing balances,
/// and handling token transfers and allowances.

#[starknet::interface]
pub trait IERC20<TContractState> {
    /// Retrieves the name of the token
    ///
    /// # Returns
    /// * `ByteArray` The name of the token as a byte array
    fn name(self: @TContractState) -> ByteArray;
    /// Retrieves the symbol of the token
    ///
    /// # Returns
    /// * `ByteArray` The symbol of the token as a byte array
    fn symbol(self: @TContractState) -> ByteArray;
    /// Retrieves the number of decimals used by the token
    ///
    /// # Returns
    /// * `u8` The number of decimals used by the token
    fn decimals(self: @TContractState) -> u8;
    /// Retrieves the total supply of the token
    ///
    /// # Returns
    /// * `u256` The total supply of the token
    fn total_supply(self: @TContractState) -> u256;
    /// Retrieves the balance of a specific account
    ///
    /// # Parameters
    /// * `account` - The contract address of the account to check the balance for
    ///
    /// # Returns
    /// * `u256` The balance of the specified account
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    /// Retrieves the allowance granted to a spender by an owner
    ///
    /// # Parameters
    /// * `owner` - The contract address of the owner
    /// * `spender` - The contract address of the spender
    ///
    /// # Returns
    /// * `u256` The amount of tokens that the spender is allowed to spend on behalf of the owner
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    /// Approves a spender to spend a specified amount of tokens on behalf of the caller
    ///
    /// # Parameters
    /// * `spender` - The contract address of the spender
    /// * `amount` - The amount of tokens to approve for spending
    ///
    /// # Returns
    /// * `bool` A boolean indicating whether the approval was successful
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    /// Transfers tokens from the caller to a recipient
    ///
    /// # Parameters
    /// * `recipient` - The contract address of the recipient
    /// * `amount` - The amount of tokens to transfer
    ///
    /// # Returns
    /// * `bool` A boolean indicating whether the transfer was successful
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    /// Transfers tokens from one account to another
    ///
    /// # Parameters
    /// * `sender` - The contract address of the sender
    /// * `recipient` - The contract address of the recipient
    /// * `amount` - The amount of tokens to transfer
    ///
    /// # Returns
    /// * `bool` A boolean indicating whether the transfer was successful
    fn transfer_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    ) -> bool;
}
