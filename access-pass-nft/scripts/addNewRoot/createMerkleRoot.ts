import { getRoot, mockGetProof, mockGetRoot } from "../utils/merkle-tree";
//import { exec } from 'child_process';
import { METADATA_URI, PROJECT_ID, ROOT_NAME, VOYAGE_TABLE_NAME } from "./config";
import * as fs from "fs";
import { uploadFileIpfs } from "../utils/ipfs";

//const scriptPath = './addNewRoot.sh';

/**
 * @note Creates leaves & root, submits the in a JSON to IPFS and
 * submits the root to the contract
 */
export async function createMerkleRoot() {
    const {root, leaves} = await getRoot(PROJECT_ID, VOYAGE_TABLE_NAME);
    console.log("root", root);

    let record = {
        root: root,
        snapshot: leaves,
    };

    let json = JSON.stringify(record);
    fs.writeFileSync(
        `./scripts/archive/leaves-${ROOT_NAME}.json`,
        json
    );

    const leavesCid = await uploadFileIpfs(
      `./scripts/archive/leaves-${ROOT_NAME}.json`,
      `${ROOT_NAME} Leaves`
    );

    // console.log("LEAVES CID: ", leavesCid);

    /// UNCOMMENT IF YOU WISH TO SUBMIT A ROOT 
    // exec(`sh ${scriptPath} ${root} ${METADATA_URI}`, (error, stdout, stderr) => {
    //     if (error) {
    //       console.error(`Error executing script: ${error}`);
    //       return;
    //     }
      
    //     console.log('Script executed successfully.');
    //     console.log('Script output:', stdout);
    // });
}

export async function mockCreateMerkleRoot() {
  const {root, leaves} = await mockGetRoot(
    ['0xf8f6b70a36f4398f0853a311dc6699aba8333cc1', '0x45556408e543158f74403e882e3c8c23ecd9f732'],
    [3, 3]
  );
  console.log("root", root);

  let record = {
      root: root,
      snapshot: leaves,
  };

  let json = JSON.stringify(record);
  fs.writeFileSync(
      `./scripts/archive/leaves-${ROOT_NAME}-single-account.json`,
      json
  );
}

export async function mockGetProofTree() {
  const proof = await mockGetProof(
    ['0xf8f6b70a36f4398f0853a311dc6699aba8333cc1', '0x45556408e543158f74403e882e3c8c23ecd9f732'],
    [3, 3],
    '0xf8f6b70a36f4398f0853a311dc6699aba8333cc1',
    3
  );
  console.log("proof", proof);
}

createMerkleRoot();