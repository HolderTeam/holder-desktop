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
            string? desc = null;
            if (item.has_member("desc")) { // LCOV_EXCL_BR_LINE
                var desc_node = item.get_member("desc"); // LCOV_EXCL_BR_LINE
                if (desc_node != null && desc_node.get_node_type() != Json.NodeType.NULL) { // LCOV_EXCL_BR_LINE
                    desc = item.get_string_member("desc");
                }
            }
            out_list.add(new ProjectResource( // LCOV_EXCL_BR_LINE
                ApiParsersCommon.string_member_or_empty(item, "resource_id"),
                ApiParsersCommon.string_member_or_empty(item, "project_id"),
                ApiParsersCommon.string_member_or_empty(item, "kind"),
                ApiParsersCommon.string_member_or_empty(item, "uri"),
                ApiParsersCommon.string_member_or_empty(item, "label"),
                desc,
                item.has_member("created_at") ? item.get_int_member("created_at") : 0,
                item.has_member("updated_at") ? item.get_int_member("updated_at") : 0
            ));
        }
        return out_list; // LCOV_EXCL_BR_LINE
    }
}

}
