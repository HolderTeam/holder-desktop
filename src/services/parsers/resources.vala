namespace HolderLinux {

public class ApiParsersResources { // LCOV_EXCL_LINE
    public static Gee.ArrayList<ProjectResource> parse_resources(Json.Object root) throws Error { // LCOV_EXCL_BR_LINE
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for resources response");
        }

        var out_list = new Gee.ArrayList<ProjectResource>();
        var data = root.get_array_member("data"); // LCOV_EXCL_BR_LINE
        for (uint i = 0; i < data.get_length(); i++) { // LCOV_EXCL_BR_LINE
            var item = data.get_object_element(i); // LCOV_EXCL_BR_LINE
            var metadata = new Gee.HashMap<string, Gee.ArrayList<string>>();
            if (item.has_member("metadata")) {
                var metadata_object = item.get_object_member("metadata");
                foreach (var key in metadata_object.get_members()) {
                    var values = new Gee.ArrayList<string>();
                    var array = metadata_object.get_array_member(key);
                    for (uint value_index = 0; value_index < array.get_length(); value_index++) {
                        values.add(array.get_string_element(value_index));
                    }
                    metadata.set(key, values);
                }
            }

            var assets = new Gee.ArrayList<ResourceAsset>();
            if (item.has_member("assets")) {
                var assets_array = item.get_array_member("assets");
                for (uint asset_index = 0; asset_index < assets_array.get_length(); asset_index++) {
                    var asset_object = assets_array.get_object_element(asset_index);
                    var placements = new Gee.ArrayList<AssetPlacement>();
                    if (asset_object.has_member("placements")) {
                        var placements_array = asset_object.get_array_member("placements");
                        for (uint placement_index = 0;
                             placement_index < placements_array.get_length();
                             placement_index++) {
                            var placement = placements_array.get_object_element(placement_index);
                            placements.add(new AssetPlacement(
                                ApiParsersCommon.string_member_or_empty(placement, "placement_id"),
                                ApiParsersCommon.string_member_or_empty(placement, "location_id"),
                                ApiParsersCommon.string_member_or_empty(placement, "encoding"),
                                placement.has_member("stored_byte_size")
                                    ? placement.get_int_member("stored_byte_size")
                                    : 0
                            ));
                        }
                    }
                    assets.add(new ResourceAsset(
                        ApiParsersCommon.string_member_or_empty(asset_object, "asset_id"),
                        ApiParsersCommon.string_member_or_empty(asset_object, "resource_id"),
                        ApiParsersCommon.string_member_or_empty(asset_object, "original_filename"),
                        ApiParsersCommon.string_member_or_empty(asset_object, "media_type"),
                        asset_object.has_member("byte_size") ? asset_object.get_int_member("byte_size") : 0,
                        ApiParsersCommon.string_member_or_empty(asset_object, "plaintext_sha256"),
                        placements
                    ));
                }
            }
            var identifier = metadata.get("identifier");
            var descriptions = metadata.get("description");
            out_list.add(new ProjectResource( // LCOV_EXCL_BR_LINE
                ApiParsersCommon.string_member_or_empty(item, "resource_id"),
                ApiParsersCommon.string_member_or_empty(item, "project_id"),
                ApiParsersCommon.string_member_or_empty(item, "type"),
                identifier != null && identifier.size > 0 ? identifier[0] : "",
                ApiParsersCommon.string_member_or_empty(item, "label"),
                descriptions != null && descriptions.size > 0 ? descriptions[0] : null,
                item.has_member("created_at") ? item.get_int_member("created_at") : 0,
                item.has_member("updated_at") ? item.get_int_member("updated_at") : 0,
                metadata,
                assets
            ));
        }
        return out_list; // LCOV_EXCL_BR_LINE
    }

    public static StorageLocationList parse_locations(Json.Object root) throws Error {
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for locations response");
        }
        var locations = new Gee.ArrayList<StorageLocation>();
        var data = root.get_array_member("data");
        for (uint i = 0; i < data.get_length(); i++) {
            var item = data.get_object_element(i);
            var configuration = new Gee.HashMap<string, string>();
            if (item.has_member("configuration")) {
                var config = item.get_object_member("configuration");
                foreach (var key in config.get_members()) {
                    configuration.set(key, ApiParsersCommon.string_member_or_empty(config, key));
                }
            }
            string? preview = null;
            if (item.has_member("binding_preview") &&
                item.get_member("binding_preview").get_node_type() != Json.NodeType.NULL) {
                preview = item.get_string_member("binding_preview");
            }
            locations.add(new StorageLocation(
                ApiParsersCommon.string_member_or_empty(item, "location_id"),
                ApiParsersCommon.string_member_or_empty(item, "project_id"),
                ApiParsersCommon.string_member_or_empty(item, "name"),
                ApiParsersCommon.string_member_or_empty(item, "provider"),
                configuration,
                item.has_member("bound") && item.get_boolean_member("bound"),
                preview
            ));
        }
        string? preferred = null;
        if (root.has_member("preferred_location_id") &&
            root.get_member("preferred_location_id").get_node_type() != Json.NodeType.NULL) {
            preferred = root.get_string_member("preferred_location_id");
        }
        return new StorageLocationList(locations, preferred);
    }

    public static AssetImportJob parse_import_job(Json.Object root) throws Error {
        if (!root.has_member("data")) {
            throw new ApiError.PROTOCOL("Missing data for import job response");
        }
        var data = root.get_object_member("data");
        return new AssetImportJob(
            ApiParsersCommon.string_member_or_empty(data, "job_id"),
            ApiParsersCommon.string_member_or_empty(data, "status"),
            nullable_string(data, "resource_id"),
            nullable_string(data, "asset_id"),
            data.has_member("duplicate_reused") && data.get_boolean_member("duplicate_reused"),
            data.has_member("link_created") && data.get_boolean_member("link_created"),
            nullable_string(data, "error")
        );
    }

    private static string? nullable_string(Json.Object object, string member) {
        if (!object.has_member(member) ||
            object.get_member(member).get_node_type() == Json.NodeType.NULL) {
            return null;
        }
        return object.get_string_member(member);
    }
}

}
