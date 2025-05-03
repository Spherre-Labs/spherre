use starknet::ContractAddress;

#[starknet::interface]
pub trait IMockNFT<TContractState> {
    fn mint(ref self: TContractState, recipient: ContractAddress, token_id: u256) -> bool;
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
}

#[starknet::contract]
pub mod MockNFT {
    use core::num::traits::Zero;
    use starknet::ContractAddress;
    use starknet::storage::{Map, StorageMapReadAccess};
    use core::starknet::storage::{StoragePathEntry, StoragePointerWriteAccess};
    use super::IMockNFT;

    #[storage]
    pub struct Storage {
        owners: Map<u256, ContractAddress>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Transfer: Transfer,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
    }

    #[abi(embed_v0)]
    impl MockNFTImpl of IMockNFT<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, token_id: u256) -> bool {
            assert(!recipient.is_zero(), 'Invalid recipient');
            assert(self.owners.read(token_id).is_zero(), 'Token already minted');

            self.owners.entry(token_id).write(recipient);

            self.emit(Transfer { from: Zero::zero(), to: recipient, token_id });

            true
        }

        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            let owner = self.owners.read(token_id);
            assert(!owner.is_zero(), 'Invalid token ID');
            owner
        }
    }
}
