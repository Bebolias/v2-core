import { getRoot } from "../utils/merkle-tree";
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

    console.log("LEAVES CID: ", leavesCid);

    // exec(`sh ${scriptPath} ${root} ${METADATA_URI}`, (error, stdout, stderr) => {
    //     if (error) {
    //       console.error(`Error executing script: ${error}`);
    //       return;
    //     }
      
    //     console.log('Script executed successfully.');
    //     console.log('Script output:', stdout);
    // });
}

createMerkleRoot();