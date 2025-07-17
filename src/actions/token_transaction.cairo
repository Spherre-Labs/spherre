//! This module implements the TokenTransaction component, which allows users to propose and execute
//! token transactions.
//! It includes methods for proposing, retrieving, and executing token transactions.
//!
//! The comment documentation of the public entrypoints can be found in the interface
//! `ITokenTransaction`.

#[starknet::component]
pub mod TokenTransaction {
    use core::num::traits::Zero;
    use openzeppelin_security::PausableComponent::InternalImpl as PausableInternalImpl;
    use openzeppelin_security::pausable::PausableComponent;
    use spherre::account_data;
    use spherre::account_data::AccountData::InternalImpl;
    use spherre::account_data::AccountData::InternalTrait;
    use spherre::components::permission_control;
    use spherre::components::treasury_handler;
    use spherre::components::treasury_handler::TreasuryHandler::InternalImpl as TreasuryHandlerInternalImpl;
    use spherre::components::treasury_handler::TreasuryHandler::InternalTrait as TreasuryHandlerInternalTrait;
    use spherre::components::treasury_handler::TreasuryHandler::TreasuryHandlerImpl;
    use spherre::errors::Errors;
    use spherre::interfaces::iaccount_data::IAccountData;

    use spherre::interfaces::itoken_tx::ITokenTransaction;
    use spherre::interfaces::itreasury_handler::ITreasuryHandler;
    use spherre::types::{TokenTransactionData, Transaction};
    use spherre::types::{TransactionType};
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_contract_address};

    #[storage]
    pub struct Storage {
        token_transactions: Map<u256, TokenTransactionData>,
        token_transaction_ids: Vec<u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TokenTransactionProposed: TokenTransactionProposed,
        TokenTransactionExecuted: TokenTransactionExecuted,
    }


    #[derive(Drop, starknet::Event)]
    struct TokenTransactionProposed {
        #[key]
        id: u256,
        token: ContractAddress,
        amount: u256,
        recipient: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct TokenTransactionExecuted {
        #[key]
        id: u256,
        token: ContractAddress,
        amount: u256,
        recipient: ContractAddress,
    }


    #[embeddable_as(TokenTransaction)]
    pub impl TokenTransactionImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl AccountData: account_data::AccountData::HasComponent<TContractState>,
        impl PermissionControl: permission_control::PermissionControl::HasComponent<TContractState>,
        impl Pausable: PausableComponent::HasComponent<TContractState>,
        impl TreasuryHandler: treasury_handler::TreasuryHandler::HasComponent<TContractState>,
    > of ITokenTransaction<ComponentState<TContractState>> {
        fn propose_token_transaction(
            ref self: ComponentState<TContractState>,
            token: ContractAddress,
            amount: u256,
            recipient: ContractAddress,
        ) -> u256 {
            // check that token and recipient are not zero addresses
            assert(token.is_non_zero(), Errors::ERR_NON_ZERO_ADDRESS_TOKEN);
            assert(recipient.is_non_zero(), Errors::ERR_NON_ZERO_ADDRESS_RECIPIENT);
            // validate amount greater than 0
            assert(amount > 0, Errors::ERR_INVALID_AMOUNT);
            // check that the recipient address is not the account address
            let account_address = get_contract_address();
            assert(recipient != account_address, Errors::ERR_RECIPIENT_CANNOT_BE_ACCOUNT);
            // check if balance of the token is greater than amount using TreasuryHandler
            let treasury_handler = get_dep_component!(@self, TreasuryHandler);
            assert(
                treasury_handler.get_token_balance(token) >= amount,
                Errors::ERR_INSUFFICIENT_TOKEN_AMOUNT,
            );
            let mut account_data_comp = get_dep_component_mut!(ref self, AccountData);
            // Create the transaction in account data and get the id
            let tx_id = account_data_comp.create_transaction(TransactionType::TOKEN_SEND);
            // Create the token transaction data
            let token_tx_data = TokenTransactionData { token, amount, recipient };
            // save the token transaction data to storage with
            self.token_transactions.entry(tx_id).write(token_tx_data);
            self.token_transaction_ids.append().write(tx_id);

            // emit event
            self.emit(TokenTransactionProposed { id: tx_id, token, amount, recipient });
            tx_id
        }
        fn get_token_transaction(
            self: @ComponentState<TContractState>, id: u256,
        ) -> TokenTransactionData {
            let account_data_comp = get_dep_component!(self, AccountData);
            let transaction: Transaction = account_data_comp.get_transaction(id);
            // verify the transsaction type
            assert(
                transaction.tx_type == TransactionType::TOKEN_SEND,
                Errors::ERR_INVALID_TOKEN_TRANSACTION,
            );
            self.token_transactions.entry(id).read()
        }
        fn token_transaction_list(
            self: @ComponentState<TContractState>,
        ) -> Array<TokenTransactionData> {
            let mut array: Array<TokenTransactionData> = array![];
            let range_stop = self.token_transaction_ids.len();
            for index in 0..range_stop {
                let id = self.token_transaction_ids.at(index).read();
                let tx = self.token_transactions.entry(id).read();
                array.append(tx);
            };
            array
        }
        fn execute_token_transaction(ref self: ComponentState<TContractState>, id: u256) {
            self.assert_is_valid_token_transaction(id);
            let token_transaction = self.get_token_transaction(id);
            // check if balance of the token is greater than amount using TreasuryHandler
            let treasury_handler = get_dep_component!(@self, TreasuryHandler);
            assert(
                treasury_handler
                    .get_token_balance(token_transaction.token) >= token_transaction
                    .amount,
                Errors::ERR_INSUFFICIENT_TOKEN_AMOUNT,
            );
            let mut account_data_comp = get_dep_component_mut!(ref self, AccountData);
            // execute the transaction in account data. all check is done there
            account_data_comp.execute_transaction(id);
            // send the token to the recipient using TreasuryHandler
            let mut treasury_handler_mut = get_dep_component_mut!(ref self, TreasuryHandler);
            treasury_handler_mut
                ._transfer_token(
                    token_transaction.token, token_transaction.recipient, token_transaction.amount,
                );
            // emit event
            self
                .emit(
                    TokenTransactionExecuted {
                        id,
                        token: token_transaction.token,
                        amount: token_transaction.amount,
                        recipient: token_transaction.recipient,
                    },
                );
        }
    }
    #[generate_trait]
    pub impl PrivateImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl AccountData: account_data::AccountData::HasComponent<TContractState>,
        impl PermissionControl: permission_control::PermissionControl::HasComponent<TContractState>,
        impl Pausable: PausableComponent::HasComponent<TContractState>,
        impl TreasuryHandler: treasury_handler::TreasuryHandler::HasComponent<TContractState>,
    > of PrivateTrait<TContractState> {
        /// Asserts that the transaction with the given ID is a valid token transaction.
        ///
        /// # Parameters
        /// * `id` - The ID of the transaction to validate.
        ///
        /// # Panics
        /// This function raises an error if the transaction with the given ID does not exist.
        /// This function raises an error if the transaction is not a token transaction.
        fn assert_is_valid_token_transaction(self: @ComponentState<TContractState>, id: u256) {
            let account_data_comp = get_dep_component!(self, AccountData);
            let transaction: Transaction = account_data_comp.get_transaction(id);
            // verify the transaction type
            assert(
                transaction.tx_type == TransactionType::TOKEN_SEND,
                Errors::ERR_INVALID_TOKEN_TRANSACTION,
            );
        }
    }
}

