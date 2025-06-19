#[starknet::component]
pub mod TreasuryHandler {
    use core::num::traits::Zero;
    use spherre::errors::Errors;
    use spherre::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use spherre::interfaces::ierc721::{IERC721Dispatcher, IERC721DispatcherTrait};
    use spherre::interfaces::itreasury_handler::ITreasuryHandler;
    use starknet::{ContractAddress, get_contract_address};

    #[storage]
    pub struct Storage {}

    /// Events emitted by this component.
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TokenTransferred: TokenTransferred,
        NftTransferred: NftTransferred,
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
            IERC20Dispatcher { contract_address: token_address }.balance_of(account)
        }
        fn is_nft_owner(
            self: @ComponentState<TContractState>, nft_address: ContractAddress, token_id: u256,
        ) -> bool {
            let account = get_contract_address();
            let owner = IERC721Dispatcher { contract_address: nft_address }.owner_of(token_id);
            account == owner
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
    }
}
