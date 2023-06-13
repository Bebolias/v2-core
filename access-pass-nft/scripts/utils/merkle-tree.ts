import { MerkleTree } from "merkletreejs";
import keccak256 from "keccak256";
import { BigNumber, ethers } from "ethers";
import { getLeaves } from "./getLeaves";

export type LeafEntry = {
  owner: string;
  metadataURI?: string | undefined;
  badgesCount: number;
}

export const getLeaf = (address: string, badgesCount: number): Buffer => {
  return Buffer.from(
    ethers.utils
      .solidityKeccak256(["address", "uint256"], [address, badgesCount])
      .slice(2),
    "hex"
  );
};

export const getMerkleTree = async (projectId: string, tableName: string): Promise<MerkleTree> => {

  // get info from bigQ
  const leafEntry = await getLeaves(projectId, tableName);

  const leafNodes = leafEntry.map((entry) => {
    return getLeaf(entry.owner, entry.badgesCount);
  });

  const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true });

  return merkleTree;
};

export const getRoot = async (projectId: string, tableName: string): Promise<string> => {
  const merkleTree = await getMerkleTree(projectId, tableName);

  return merkleTree.getHexRoot();
};

export const getProof = async (
  address: string,
  badgesCount: number,
  projectId: string,
  tableName: string
): Promise<string[]> => {
  const merkleTree = await getMerkleTree(projectId, tableName);

  const proof = merkleTree.getHexProof(getLeaf(address, badgesCount));

  if (proof.length === 0) {
    throw `Cannot prove something that is not in tree`;
  }

  return proof;
};

export const getTokenId = (
  account: string,
  merkleRoot: string,
  badgeType: number
): BigNumber => {
  return BigNumber.from(
    ethers.utils.solidityKeccak256(
      ["address", "bytes32", "uint96"],
      [account, merkleRoot, badgeType]
    )
  );
};

//// MOCKS USED FOR TESTING

export const mockGetMerkleTree = async (owners: string[], badgesCounts: number[]): Promise<MerkleTree> => {

  // get info from bigQ
  const leafEntry = owners.map((_, i) => {
    return {
      owner: owners[i],
      badgesCount: badgesCounts[i]
  }});

  const leafNodes = leafEntry.map((entry) => {
    return getLeaf(entry.owner, entry.badgesCount);
  });

  const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true });

  return merkleTree;
};

export const mockGetRoot = async (): Promise<string> => {
  const merkleTree = await mockGetMerkleTree();

  return merkleTree.getHexRoot();
};

export const mockGetProof = async (
  address: string,
  badgesCount: number
): Promise<string[]> => {
  const merkleTree = await mockGetMerkleTree();

  const proof = merkleTree.getHexProof(getLeaf(address, badgesCount));

  if (proof.length === 0) {
    throw `Cannot prove something that is not in tree`;
  }

  return proof;
};