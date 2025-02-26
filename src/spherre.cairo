#[starknet::contract]
pub mod Spherre {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        owner: ContractAddress,
    }
}
