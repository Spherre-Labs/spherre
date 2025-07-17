#[starknet::component]
pub mod SmartTokenLockTransactionComponent {
    use core::num::traits::Zero;
    use openzeppelin_security::PausableComponent::InternalImpl as PausableInternalImpl;
    use openzeppelin_security::pausable::PausableComponent;
    use spherre::account_data;
    use spherre::account_data::AccountData::InternalImpl;
    use spherre::account_data::AccountData::InternalTrait;
    use spherre::components::treasury_handler::TreasuryHandler::{
        InternalImpl as TreasuryHandlerInternalImpl, TreasuryHandlerImpl,
    };
    use spherre::components::{permission_control, treasury_handler};
    use spherre::errors::Errors;
    use spherre::interfaces::iaccount_data::IAccountData;
    use spherre::interfaces::ismart_token_lock_transaction::ISmartTokenLockTransaction;
    use spherre::interfaces::itreasury_handler::ITreasuryHandler;
    use spherre::types::{SmartTokenLockTransaction, Transaction, TransactionType};
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use starknet::{get_block_timestamp};


    #[storage]
    pub struct Storage {
        smart_token_lock_transactions: Map<u256, SmartTokenLockTransaction>,
        smart_token_lock_transaction_ids: Vec<u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        SmartTokenLockTransactionProposed: SmartTokenLockTransactionProposed,
        SmartTokenLockTransactionExecuted: SmartTokenLockTransactionExecuted,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SmartTokenLockTransactionProposed {
        #[key]
        id: u256,
        token: ContractAddress,
        amount: u256,
        duration: u64,
    }
    #[derive(Drop, starknet::Event)]
    pub struct SmartTokenLockTransactionExecuted {
        #[key]
        transaction_id: u256,
        #[key]
        lock_id: u256,
        token: ContractAddress,
        amount: u256,
        duration: u64,
        date_executed: u64,
    }

    #[embeddable_as(SmartTokenLockTransactionComponent)]
    pub impl SmartTokenLockTransactionComponentImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl TreasuryHandler: treasury_handler::TreasuryHandler::HasComponent<TContractState>,
        impl AccountData: account_data::AccountData::HasComponent<TContractState>,
        impl PermissionControl: permission_control::PermissionControl::HasComponent<TContractState>,
        impl Pausable: PausableComponent::HasComponent<TContractState>,
    > of ISmartTokenLockTransaction<ComponentState<TContractState>> {
        fn propose_smart_token_lock_transaction(
            ref self: ComponentState<TContractState>,
            token: ContractAddress,
            amount: u256,
            duration: u64,
        ) -> u256 {
            assert(token.is_non_zero(), Errors::ERR_NON_ZERO_ADDRESS_TOKEN);
            assert(amount > 0, Errors::ERR_INVALID_AMOUNT);
            assert(duration > 0, Errors::ERR_INVALID_TOKEN_LOCK_DURATION);

            let mut treasury_handler_comp = get_dep_component_mut!(ref self, TreasuryHandler);
            let token_balance = treasury_handler_comp.get_token_balance(token);

            assert(token_balance >= amount, Errors::ERR_INSUFFICIENT_TOKEN_AMOUNT);

            let mut account_data_comp = get_dep_component_mut!(ref self, AccountData);
            let tx_id = account_data_comp.create_transaction(TransactionType::SMART_TOKEN_LOCK);

            let smart_token_lock_tx = SmartTokenLockTransaction {
                token, amount, duration, transaction_id: tx_id,
            };
            self.smart_token_lock_transactions.entry(tx_id).write(smart_token_lock_tx);
            self.smart_token_lock_transaction_ids.append().write(tx_id);

            self.emit(SmartTokenLockTransactionProposed { id: tx_id, token, amount, duration });

            tx_id
        }

        fn get_smart_token_lock_transaction(
            self: @ComponentState<TContractState>, transaction_id: u256,
        ) -> SmartTokenLockTransaction {
            let account_data_comp = get_dep_component!(self, AccountData);
            let transaction: Transaction = account_data_comp.get_transaction(transaction_id);

            assert(
                transaction.tx_type == TransactionType::SMART_TOKEN_LOCK,
                Errors::ERR_INVALID_SMART_TOKEN_LOCK_TRANSACTION,
            );

            self.smart_token_lock_transactions.entry(transaction_id).read()
        }
        fn smart_token_lock_transaction_list(
            self: @ComponentState<TContractState>,
        ) -> Array<SmartTokenLockTransaction> {
            let mut smart_lock_tx_array = array![];
            let range_stop = self.smart_token_lock_transaction_ids.len();

            for index in 0..range_stop {
                let id = self.smart_token_lock_transaction_ids.at(index).read();
                let tx = self.smart_token_lock_transactions.entry(id).read();
                smart_lock_tx_array.append(tx);
            };

            smart_lock_tx_array
        }
        fn execute_smart_token_lock_transaction(
            ref self: ComponentState<TContractState>, transaction_id: u256,
        ) -> u256 {
            let pausable = get_dep_component!(@self, Pausable);
            pausable.assert_not_paused();

            let smart_lock_tx = self.get_smart_token_lock_transaction(transaction_id);

            let treasury_handler_comp = get_dep_component!(@self, TreasuryHandler);
            let current_balance = treasury_handler_comp.get_token_balance(smart_lock_tx.token);
            assert(current_balance >= smart_lock_tx.amount, Errors::ERR_INSUFFICIENT_TOKEN_AMOUNT);

            let mut account_data_comp = get_dep_component_mut!(ref self, AccountData);
            account_data_comp.execute_transaction(transaction_id);

            let mut treasury_handler_comp_mut = get_dep_component_mut!(ref self, TreasuryHandler);
            let lock_id = treasury_handler_comp_mut
                ._lock_tokens(smart_lock_tx.token, smart_lock_tx.amount, smart_lock_tx.duration);

            // Event
            self
                .emit(
                    Event::SmartTokenLockTransactionExecuted(
                        SmartTokenLockTransactionExecuted {
                            transaction_id,
                            lock_id,
                            token: smart_lock_tx.token,
                            amount: smart_lock_tx.amount,
                            duration: smart_lock_tx.duration,
                            date_executed: get_block_timestamp(),
                        },
                    ),
                );
            lock_id
        }
    }
}
