const isExtensionOrigin = (origin) => typeof origin === "string" &&
    /^(chrome|moz)-extension:\/\/[a-z0-9-]+$/i.test(origin);

module.exports = {isExtensionOrigin};
