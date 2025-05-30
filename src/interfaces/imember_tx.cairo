use spherre::types::MemberRemoveData;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IMemberRemoveTransaction<TContractState> {
    fn propose_remove_member_transaction(
        ref self: TContractState, member_address: ContractAddress
    ) -> u256;
    fn get_member_removal_transaction(
        self: @TContractState, transaction_id: u256
    ) -> MemberRemoveData;
    fn member_removal_transaction_list(self: @TContractState) -> Array<MemberRemoveData>;
}
