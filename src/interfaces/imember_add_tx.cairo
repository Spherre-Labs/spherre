use spherre::types::MemberAddData;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IMemberAddTransaction<TContractState> {
    fn propose_member_add_transaction(
        ref self: TContractState, member: ContractAddress, permissions: u8
    ) -> u256;
    fn get_member_add_transaction(self: @TContractState, transaction_id: u256) -> MemberAddData;
    fn member_add_transaction_list(self: @TContractState) -> Array<MemberAddData>;
    fn execute_member_add_transaction(
        ref self: TContractState, transaction_id: u256
    );
}
