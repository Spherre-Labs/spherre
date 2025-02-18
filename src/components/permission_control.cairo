#[starknet::component]
pub mod PermissionControl {
    use starknet::{ContractAddress};
    use starknet::storage::{Map};
    #[storage]
    pub struct Storage {
        member_permission: Map<(felt252, ContractAddress), bool>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    #[derive(Drop, starknet::Event)]
    pub struct PermissionGranted {
        pub permission: felt252,
        pub member: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    pub struct PermissionRevoked {
        pub permission: felt252,
        pub account: ContractAddress
    }
}
