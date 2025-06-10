use starknet::ContractAddress;

#[starknet::interface]
pub trait IMockNFT<TContractState> {
    fn mint(ref self: TContractState, recipient: ContractAddress, token_id: u256) -> bool;
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn approve(ref self: TContractState, operator: ContractAddress, token_id: u256);
    fn transfer_from(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256
    );
}



#[starknet::contract]
pub mod MockNFT {
    use super::IMockNFT;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use starknet::ContractAddress;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC721 Mixin
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
    ) {
        let name = "MockNFT";
        let symbol = "MNFT";
        let base_uri = "https://api.example.com/v1/";

        self.erc721.initializer(name, symbol, base_uri);
        
    }
    #[abi(embed_v0)]
    impl MockNFTImpl of IMockNFT<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, token_id: u256) -> bool {

            self.erc721.mint(recipient, token_id);
            true
        }

        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            self.erc721.owner_of(token_id)
        }
        fn approve(
            ref self: ContractState,
            operator: ContractAddress,
            token_id: u256
        ) {
            self.erc721.approve(operator, token_id);
        }
        fn transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256
        ) {
            self.erc721.transfer_from(from, to, token_id);
        }
    }
}