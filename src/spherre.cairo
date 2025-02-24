#[starknet::contract]
pub mod Spherre {
    use core::starknet::{
        storage::{StorableStoragePointerReadAccess, StoragePointerWriteAccess},
        {ContractAddress, contract_address_const},
    };

    #[storage]
    struct Storage {
        owner: ContractAddress,
        name: ByteArray,
        description: ByteArray,
    }

    pub mod Errors {
        pub const ERR_DEPLOYER_ZERO: felt252 = 'Deployer should not be zero';
        pub const ERR_OWNER_ZERO: felt252 = 'Owner should not be zero';
        pub const ERR_INVALID_MEMBER_THRESHOLD: felt252 = 'Members must meet threshold';
    }

    #[constructor]
    pub fn constructor(
        ref self: ContractState,
        deployer: ContractAddress,
        owner: ContractAddress,
        name: ByteArray,
        description: ByteArray,
        members: Array<ContractAddress>,
        threshold: u64,
    ) {
        assert(deployer != contract_address_const::<0>(), Errors::ERR_DEPLOYER_ZERO);
        assert(owner != contract_address_const::<0>(), Errors::ERR_OWNER_ZERO);
        assert((members.len()).into() >= threshold, Errors::ERR_INVALID_MEMBER_THRESHOLD);
        self.name.write(name);
        self.description.write(description);
    }

    #[generate_trait]
    pub impl SpherreImpl of ISpherreImpl {
        fn get_name(self: @ContractState) -> ByteArray {
            self.name.read()
        }

        fn get_description(self: @ContractState) -> ByteArray {
            self.description.read()
        }
    }
}
