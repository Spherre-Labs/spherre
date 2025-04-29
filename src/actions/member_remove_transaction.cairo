#[starknet::component]
pub mod MemberRemoveTransaction {
    use spherre::types::MemberRemoveData;
    use starknet::storage::{Map, Vec};
    #[storage]
    pub struct Storage {
        member_remove_transactions: Map<u256, MemberRemoveData>,
        member_remove_transaction_ids: Vec<u256>
    }
}
