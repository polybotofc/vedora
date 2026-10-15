import { useEffect, useState } from "react";
import { createUseStyles } from "react-jss";
import request, { getBaseUrl } from "../../lib/request";
import { adTypes } from "./constants";
import Link from "../link";

const useStyles = createUseStyles({
    adWrapper: {},
    adImage: {
        width: '100%',
        height: 'auto',
        margin: '0 auto',
        display: 'block',
        '@media(max-width: 800px)': {
            paddingTop: '10px',
            paddingBottom: '10px',
        },
    },
})

// /user-sponsorship/:type is counted as a view, so once-per-type is enough.
// Caching the in-flight promise also keeps React StrictMode's double-invoked
// effect (mount, unmount, remount) from firing two requests.
const adRequestCache = {};

// This component is mounted on many pages. On a private server the ad endpoint
// usually has nothing to serve, so a per-mount log would flood the console
// (hundreds of identical lines). Warn at most once per ad type instead.
const warnedAdTypes = new Set();

const warnOnce = (type, message, detail) => {
    if (warnedAdTypes.has(type)) return;
    warnedAdTypes.add(type);
    console.warn(`[userAdvertisement] ${message} (type ${type})`, detail ?? '');
};

const fetchAd = (type) => {
    if (!adRequestCache[type]) {
        adRequestCache[type] = request('GET', `${getBaseUrl()}/user-sponsorship/${type}`)
            .then(adData => adData.data)
            .catch(e => {
                // Allow a later mount to retry after a transient failure.
                delete adRequestCache[type];
                throw e;
            });
    }
    return adRequestCache[type];
};

/**
 * User advertisement iframe
 * @param {{type: number; wrapperClass?: string; backupWidth?: number;}} props
 */
const UserAdvertisement = props => {
    const info = adTypes[props.type];
    const [imageUrl, setImageUrl] = useState(null);
    const [link, setLink] = useState(null);
    const [title, setTitle] = useState(null);
    const [imageLoaded, setImageLoaded] = useState(false);
    const s = useStyles();

    useEffect(() => {
        let cancelled = false;
        // A type change replaces the previous ad; drop its state so a stale
        // image is never shown for the new slot.
        setImageUrl(null);
        setLink(null);
        setTitle(null);
        setImageLoaded(false);

        fetchAd(props.type).then(data => {
            if (cancelled) return;
            let doc;
            try {
                doc = new DOMParser().parseFromString(data, 'text/html');
            } catch (e) {
                warnOnce(props.type, 'could not parse user ad document', e);
                return;
            }
            const imageElements = doc.getElementsByTagName('img');
            const aTags = doc.getElementsByTagName('a');
            const imageElement = imageElements[0];
            const aTag = aTags[0];
            const nextImageUrl = imageElement && imageElement.getAttribute('src');
            const nextLink = aTag && aTag.getAttribute('href');
            const nextTitle = aTag && aTag.getAttribute('title');
            if (!nextImageUrl || !nextLink || !nextTitle) {
                // No ad was served for this slot (the endpoint returns an empty
                // document when there is nothing to show). Stay on the reserved
                // placeholder instead of logging an error per mount.
                warnOnce(props.type, 'no user ad available');
                return;
            }
            setImageUrl(nextImageUrl);
            setTitle(nextTitle);
            setLink(nextLink);
        }).catch(e => {
            if (cancelled) return;
            // 404/503 (advertising disabled) and transient network errors are
            // expected here; warn once, keep the placeholder, do not spam.
            warnOnce(props.type, 'could not load user ad', e?.message || e);
        });

        return () => {
            cancelled = true;
        };
    }, [props.type]);

    // TODO: calculate correct height of ad when current screen width is smaller than ad width. The height is way too big on mobile.
    if (!info) throw new Error(`unexpected adType: ${props.type}`);
    if (!imageUrl) {
        return <div className={`${props?.wrapperClass || ''}`} style={{ width: props.backupWidth || '100%', height: info.height }}/>
    }
    return <div className={`${s.adWrapper} ${props?.wrapperClass || ''}`}
                style={imageLoaded ? undefined : { height: info.height, width: '100%' }}>
        <Link href={link || '#'}>
            <a title={title}>
                <img onLoad={() => {
                    setImageLoaded(true)
                }} src={imageUrl} className={s.adImage} style={{ maxWidth: info.width, maxHeight: info.height }}/>
            </a>
        </Link>
    </div>
}

export default UserAdvertisement;