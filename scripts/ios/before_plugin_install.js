const fs = require('fs');
const { execSync } = require("child_process");

module.exports = async function(ctx) {
    const project = ctx.opts.projectRoot + '/platform/ios';
    console.log(`run pod repo update for cordova-plugin-moxo, this may take a while...`);
    try {
        const info = await execSync("pod repo update moxtra-specs");
        console.log(info.toString());
    } catch (e) {
        console.log(`'pod repo update' failed because of:\n${e}\nPlease try run 'pod install --repo-update' command in ${project} mannully later.`);
    }
};