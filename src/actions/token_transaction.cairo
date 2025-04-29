#[starknet::component]
pub mod TokenTransaction {
    use core::num::traits::Zero;
    use openzeppelin_security::PausableComponent::InternalImpl as PausableInternalImpl;
    use openzeppelin_security::pausable::PausableComponent;
    use spherre::account_data::AccountData::InternalImpl;
    use spherre::account_data::AccountData::InternalTrait;
    use spherre::account_data;
    use spherre::components::permission_control;
    use spherre::errors::Errors;
    use spherre::interfaces::iaccount_data::IAccountData;

    use spherre::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use spherre::interfaces::itoken_tx::ITokenTransaction;
    use spherre::types::{TokenTransactionData, Transaction};
    use spherre::types::{TransactionType};
    use starknet::storage::{
        Map, StoragePathEntry, Vec, VecTrait, MutableVecTrait, StoragePointerReadAccess,
        StoragePointerWriteAccess
    };
    use starknet::{ContractAddress, get_contract_address};

    #[storage]
    pub struct Storage {
        token_transactions: Map<u256, TokenTransactionData>,
        token_transaction_ids: Vec<u256>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TokenTransactionCreated: TokenTransactionCreated
    }


    #[derive(Drop, starknet::Event)]
    struct TokenTransactionCreated {
        id: u256,
        token: ContractAddress,
        amount: u256,
        recipient: ContractAddress
    }


    #[embeddable_as(TokenTransaction)]
    pub impl TokenTransactionImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl AccountData: account_data::AccountData::HasComponent<TContractState>,
        impl PermissionControl: permission_control::PermissionControl::HasComponent<TContractState>,
        impl Pausable: PausableComponent::HasComponent<TContractState>,
    > of ITokenTransaction<ComponentState<TContractState>> {
        fn propose_token_transaction(
            ref self: ComponentState<TContractState>,
            token: ContractAddress,
            amount: u256,
            recipient: ContractAddress
        ) -> u256 {
            // check that token and recipient are not zero addresses
            assert(token.is_non_zero(), Errors::ERR_NON_ZERO_ADDRESS_TOKEN);
            assert(recipient.is_non_zero(), Errors::ERR_NON_ZERO_ADDRESS_RECIPIENT);
            // validate amount greater than 0
            assert(amount > 0, Errors::ERR_INVALID_AMOUNT);
            // check that the recipient address is not the account address
            let account_address = get_contract_address();
            assert(recipient != account_address, Errors::ERR_RECIPIENT_CANNOT_BE_ACCOUNT);
            // check if balance of the token is greater than amount
            let erc20_dispatcher = IERC20Dispatcher { contract_address: token };
            assert(
                erc20_dispatcher.balance_of(account_address) >= amount,
                Errors::ERR_INSUFFICIENT_TOKEN_AMOUNT
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
            self.emit(TokenTransactionCreated { id: tx_id, token, amount, recipient });
            tx_id
        }
        fn get_token_transaction(
            self: @ComponentState<TContractState>, id: u256
        ) -> TokenTransactionData {
            let account_data_comp = get_dep_component!(self, AccountData);
            let transaction: Transaction = account_data_comp.get_transaction(id);
            // verify the transsaction type
            assert(
                transaction.tx_type == TransactionType::TOKEN_SEND,
                Errors::ERR_INVALID_TOKEN_TRANSACTION
            );
            self.token_transactions.entry(id).read()
        }
        fn token_transaction_list(
            self: @ComponentState<TContractState>
        ) -> Array<TokenTransactionData> {
            let mut array: Array<TokenTransactionData> = array![];
            let range_stop = self.token_transaction_ids.len();
            for index in 0
                ..range_stop {
                    let id = self.token_transaction_ids.at(index).read();
                    let tx = self.token_transactions.entry(id).read();
                    array.append(tx);
                };
            array
        }
    }
}

