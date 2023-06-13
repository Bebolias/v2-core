import { getRoot, mockGetProof, mockGetRoot } from "../utils/merkle-tree";
import { exec } from 'child_process';
import { METADATA_URI, PROJECT_ID, VOYAGE_TABLE_NAME } from "./config";

const scriptPath = './addNewRoot.sh';

export async function createMerkleRoot() {
    const root = await getRoot(PROJECT_ID, VOYAGE_TABLE_NAME);
    console.log(root);

    exec(`sh ${scriptPath} ${root} ${METADATA_URI}`, (error, stdout, stderr) => {
        if (error) {
          console.error(`Error executing script: ${error}`);
          return;
        }
      
        console.log('Script executed successfully.');
        console.log('Script output:', stdout);
    });
}