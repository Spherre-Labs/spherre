#[starknet::component]
pub mod MemberAddTransaction {
    use spherre::types::PermissionEnum;
    use starknet::ContractAddress;
    use starknet::storage::{Map, Vec};

    #[storage]
    pub struct Storage {
        member_add_transactions: Map<u256, StorageMemberAddTransaction>,
        member_add_transaction_ids: Vec<u256>
    }

    // This is created because we need an array to hold the permissions info
    // and normal starknet::Store attribute does not support arrays
    #[starknet::storage_node]
    pub struct StorageMemberAddTransaction {
        member: ContractAddress,
        permissions: Vec<PermissionEnum>
    }
}
