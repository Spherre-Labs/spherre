#[starknet::component]
pub mod TreasuryHandler {
    use core::num::traits::Zero;
    use spherre::errors::Errors;
    use spherre::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use spherre::interfaces::ierc721::{IERC721Dispatcher, IERC721DispatcherTrait};
    use spherre::interfaces::itreasury_handler::ITreasuryHandler;
    use spherre::types::{SmartTokenLock, LockStatus};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess
    };
    use starknet::{ContractAddress, get_contract_address, get_block_timestamp};

    #[storage]
    pub struct Storage {
        locked_amount: Map<ContractAddress, u256>,
        smart_token_locks: Map<u256, SmartTokenLock>,
        lock_counter: u256,
    }

    /// Events emitted by this component.
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TokenTransferred: TokenTransferred,
        NftTransferred: NftTransferred,
        TokenLocked: TokenLocked,
        TokenUnlocked: TokenUnlocked,
    }

    /// Emitted when an ERC‑20 transfer succeeds.
    #[derive(Drop, starknet::Event)]
    pub struct TokenTransferred {
        pub token: ContractAddress,
        pub to: ContractAddress,
        pub amount: u256,
    }

    /// Emitted when an ERC‑721 transfer succeeds.
    #[derive(Drop, starknet::Event)]
    pub struct NftTransferred {
        pub nft: ContractAddress,
        pub to: ContractAddress,
        pub token_id: u256,
    }

    /// Emitted when tokens are locked.
    #[derive(Drop, starknet::Event)]
    pub struct TokenLocked {
        pub lock_id: u256,
        pub token: ContractAddress,
        pub amount: u256,
        pub lock_duration: u64,
    }

    /// Emitted when tokens are unlocked.
    #[derive(Drop, starknet::Event)]
    pub struct TokenUnlocked {
        pub lock_id: u256,
        pub token: ContractAddress,
        pub amount: u256,
    }

    /// External interface implementation.
    #[embeddable_as(TreasuryHandler)]
    impl TreasuryHandlerImpl<
        TContractState, +HasComponent<TContractState>,
    > of ITreasuryHandler<ComponentState<TContractState>> {
        fn get_token_balance(
            self: @ComponentState<TContractState>, token_address: ContractAddress,
        ) -> u256 {
            assert(!token_address.is_zero(), Errors::ERR_NON_ZERO_ADDRESS_TOKEN);

            let account = get_contract_address();
            let total_balance = IERC20Dispatcher { contract_address: token_address }
                .balance_of(account);
            let locked_balance = self.locked_amount.read(token_address);

            assert(total_balance >= locked_balance, Errors::ERR_INSUFFICIENT_TOKEN_AMOUNT);
            total_balance - locked_balance
        }

        fn is_nft_owner(
            self: @ComponentState<TContractState>, nft_address: ContractAddress, token_id: u256,
        ) -> bool {
            let account = get_contract_address();
            let owner = IERC721Dispatcher { contract_address: nft_address }.owner_of(token_id);
            account == owner
        }

        fn get_all_locked_plans(self: @ComponentState<TContractState>) -> Array<SmartTokenLock> {
            let mut locked_plans = array![];
            let lock_count = self.lock_counter.read();

            for i in 1
                ..lock_count
                    + 1 {
                        let lock_plan = self.smart_token_locks.read(i);
                        locked_plans.append(lock_plan);
                    };

            locked_plans
        }

        fn get_locked_plan_by_id(
            self: @ComponentState<TContractState>, lock_id: u256
        ) -> SmartTokenLock {
            self.smart_token_locks.read(lock_id)
        }
    }

    /// Internal implementation.
    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        /// Transfers `amount` of ERC‑20 `token_address` from this account to `to`.
        /// Emits a `TokenTransferred` event on success.
        ///
        /// # Parameters
        /// - `token_address` – The ERC‑20 token contract address.
        /// - `to`            – The recipient address.
        /// - `amount`        – The amount to transfer.
        fn _transfer_token(
            ref self: ComponentState<TContractState>,
            token_address: ContractAddress,
            to: ContractAddress,
            amount: u256,
        ) {
            assert(!token_address.is_zero(), Errors::ERR_NON_ZERO_ADDRESS_TOKEN);
            assert(!to.is_zero(), Errors::ERR_NON_ZERO_ADDRESS_RECIPIENT);
            assert(amount > 0, Errors::ERR_INSUFFICIENT_TOKEN_AMOUNT);

            // Check that we have enough unlocked tokens for the transfer
            let account = get_contract_address();
            let total_balance = IERC20Dispatcher { contract_address: token_address }
                .balance_of(account);
            let locked_balance = self.locked_amount.read(token_address);
            let available_balance = total_balance - locked_balance;
            assert(amount <= available_balance, Errors::ERR_INSUFFICIENT_TOKEN_AMOUNT);

            let transfer_success = IERC20Dispatcher { contract_address: token_address }
                .transfer(to, amount);
            assert(transfer_success, Errors::ERR_ERC20_TRANSFER_FAILED);

            self
                .emit(
                    Event::TokenTransferred(TokenTransferred { token: token_address, to, amount }),
                );
        }

        /// Transfers the ERC-721 `token_id` owned by this account to `to`.
        /// Emits an `NftTransferred` event on success.
        ///
        /// # Parameters
        /// * `nft_address` - The ERC-721 token contract address.
        /// * `to`          - The recipient address.
        /// * `token_id`    - The token identifier.
        fn _transfer_nft(
            ref self: ComponentState<TContractState>,
            nft_address: ContractAddress,
            to: ContractAddress,
            token_id: u256,
        ) {
            assert(!nft_address.is_zero(), Errors::ERR_NON_ZERO_ADDRESS_NFT_CONTRACT);
            assert(!to.is_zero(), Errors::ERR_NON_ZERO_ADDRESS_RECIPIENT);
            assert(self.is_nft_owner(nft_address, token_id), Errors::ERR_NFT_NOT_OWNED);

            let account = get_contract_address();
            let ierc721_dispatcher = IERC721Dispatcher { contract_address: nft_address };
            ierc721_dispatcher.approve(to, token_id); // Approve the recipient to transfer the NFT
            ierc721_dispatcher.transfer_from(account, to, token_id);

            self.emit(Event::NftTransferred(NftTransferred { nft: nft_address, to, token_id }));
        }

        /// Locks `amount` of ERC‑20 `token_address` for the specified duration.
        /// Creates a new lock plan and updates locked amounts.
        ///
        /// # Parameters
        /// - `token_address` – The ERC‑20 token contract address.
        /// - `amount`        – The amount to lock.
        /// - `lock_duration` – The lock duration in days.
        ///
        /// # Returns
        /// - `u256` – The unique lock ID.
        fn _lock_tokens(
            ref self: ComponentState<TContractState>,
            token_address: ContractAddress,
            amount: u256,
            lock_duration: u64,
        ) -> u256 {
            assert(!token_address.is_zero(), Errors::ERR_NON_ZERO_ADDRESS_TOKEN);
            assert(amount > 0, Errors::ERR_ZERO_LOCK_AMOUNT);
            assert(lock_duration > 0, Errors::ERR_ZERO_LOCK_DURATION);

            // Check that we have enough unlocked tokens to lock
            let account = get_contract_address();
            let total_balance = IERC20Dispatcher { contract_address: token_address }
                .balance_of(account);
            let current_locked = self.locked_amount.read(token_address);
            let available_balance = total_balance - current_locked;
            assert(amount <= available_balance, Errors::ERR_INSUFFICIENT_TOKEN_AMOUNT);

            // Create new lock plan
            let lock_count = self.lock_counter.read();
            let new_lock_id = lock_count + 1;

            let lock_plan = SmartTokenLock {
                token: token_address,
                date_locked: get_block_timestamp(),
                lock_duration: lock_duration,
                token_amount: amount,
                lock_status: LockStatus::LOCKED,
            };

            // Update storage
            self.smart_token_locks.write(new_lock_id, lock_plan);
            self.lock_counter.write(new_lock_id);
            self.locked_amount.write(token_address, current_locked + amount);

            // Emit event
            self
                .emit(
                    Event::TokenLocked(
                        TokenLocked {
                            lock_id: new_lock_id, token: token_address, amount, lock_duration
                        }
                    )
                );

            new_lock_id
        }

        /// Unlocks tokens from a lock plan if the lock duration has passed.
        /// Updates lock status and decreases locked amounts.
        ///
        /// # Parameters
        /// - `lock_id` – The unique lock ID.
        fn _unlock_tokens(ref self: ComponentState<TContractState>, lock_id: u256) {
            assert(lock_id > 0, Errors::ERR_ZERO_LOCK_ID);

            let mut lock_plan = self.smart_token_locks.read(lock_id);

            // Check that the lock exists and is currently locked
            assert(
                lock_plan.lock_status == LockStatus::LOCKED, Errors::ERR_LOCK_ALREADY_UNLOCKED
            );

            // Check that the lock duration has passed
            let current_time = get_block_timestamp();
            let lock_end_time = lock_plan.date_locked
                + (lock_plan.lock_duration * 86400); // 86400 seconds in a day
            assert(current_time >= lock_end_time, Errors::ERR_LOCK_DURATION_NOT_ELAPSED);

            // Update lock status
            lock_plan.lock_status = LockStatus::PAIDOUT;
            self.smart_token_locks.write(lock_id, lock_plan);

            // Update locked amounts
            let current_locked = self.locked_amount.read(lock_plan.token);
            assert(current_locked >= lock_plan.token_amount, Errors::ERR_INSUFFICIENT_TOKEN_AMOUNT);
            self.locked_amount.write(lock_plan.token, current_locked - lock_plan.token_amount);

            // Emit event
            self
                .emit(
                    Event::TokenUnlocked(
                        TokenUnlocked {
                            lock_id, token: lock_plan.token, amount: lock_plan.token_amount
                        }
                    )
                );
        }
    }
}
