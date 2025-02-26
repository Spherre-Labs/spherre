
#[starknet::component]
pub mod AccountData {
    use spherre::types::{TransactionStatus, TransactionType};
    use starknet::storage::{Map};
    use starknet::{ContractAddress};
    #[storage]
    pub struct Storage {
        transactions: Map<u256, Transaction>,
        tx_count: u256, // the transaction length
        threshold: u64, // the number of members required to approve a transaction for it to be executed
        members: Map<u64, ContractAddress>, // Map(id, member) the members of the account
        members_count: u64 // the member length
    }

    #[starknet::storage_node]
    pub struct Transaction {
        id: u256,
        tx_type: TransactionType,
        tx_status: TransactionStatus,
        date_created: u64,
        date_executed: u64,
    }
}

