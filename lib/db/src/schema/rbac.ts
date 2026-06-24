import { relations } from "drizzle-orm";
import {
  boolean,
  index,
  integer,
  jsonb,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
  uuid
} from "drizzle-orm/pg-core";

const timestamps = {
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow()
};

export const roles = pgTable(
  "roles",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    key: text("key").notNull(),
    name: text("name").notNull(),
    description: text("description"),
    level: integer("level").notNull().default(0),
    isSystem: boolean("is_system").notNull().default(true),
    isActive: boolean("is_active").notNull().default(true),
    ...timestamps
  },
  (table) => ({
    keyUnique: uniqueIndex("roles_key_unique").on(table.key),
    activeIdx: index("roles_active_idx").on(table.isActive)
  })
);

export const permissions = pgTable(
  "permissions",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    key: text("key").notNull(),
    moduleKey: text("module_key").notNull(),
    action: text("action").notNull(),
    name: text("name").notNull(),
    description: text("description"),
    isActive: boolean("is_active").notNull().default(true),
    ...timestamps
  },
  (table) => ({
    keyUnique: uniqueIndex("permissions_key_unique").on(table.key),
    moduleActionIdx: index("permissions_module_action_idx").on(table.moduleKey, table.action),
    activeIdx: index("permissions_active_idx").on(table.isActive)
  })
);

export const rolePermissions = pgTable(
  "role_permissions",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    roleId: uuid("role_id").notNull().references(() => roles.id, { onDelete: "cascade" }),
    permissionId: uuid("permission_id").notNull().references(() => permissions.id, { onDelete: "cascade" }),
    ...timestamps
  },
  (table) => ({
    rolePermissionUnique: uniqueIndex("role_permissions_role_permission_unique").on(table.roleId, table.permissionId),
    roleIdx: index("role_permissions_role_idx").on(table.roleId),
    permissionIdx: index("role_permissions_permission_idx").on(table.permissionId)
  })
);

// staffUserId intentionally has no FK because existing AUM staff user table may be named users or staff_users.
// Wire the FK after confirming the current production schema.
export const userRoles = pgTable(
  "user_roles",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    staffUserId: uuid("staff_user_id").notNull(),
    roleId: uuid("role_id").notNull().references(() => roles.id, { onDelete: "cascade" }),
    assignedByUserId: uuid("assigned_by_user_id"),
    startsAt: timestamp("starts_at", { withTimezone: true }).notNull().defaultNow(),
    endsAt: timestamp("ends_at", { withTimezone: true }),
    isPrimary: boolean("is_primary").notNull().default(false),
    ...timestamps
  },
  (table) => ({
    staffRoleUnique: uniqueIndex("user_roles_staff_role_unique").on(table.staffUserId, table.roleId),
    staffIdx: index("user_roles_staff_idx").on(table.staffUserId),
    roleIdx: index("user_roles_role_idx").on(table.roleId)
  })
);

export const moduleAccess = pgTable(
  "module_access",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    moduleKey: text("module_key").notNull(),
    moduleName: text("module_name").notNull(),
    parentModuleKey: text("parent_module_key"),
    route: text("route"),
    icon: text("icon"),
    sortOrder: integer("sort_order").notNull().default(0),
    isNavigationItem: boolean("is_navigation_item").notNull().default(true),
    isActive: boolean("is_active").notNull().default(true),
    metadata: jsonb("metadata"),
    ...timestamps
  },
  (table) => ({
    moduleKeyUnique: uniqueIndex("module_access_module_key_unique").on(table.moduleKey),
    parentIdx: index("module_access_parent_idx").on(table.parentModuleKey),
    activeNavigationIdx: index("module_access_active_navigation_idx").on(table.isActive, table.isNavigationItem)
  })
);

export const roleModuleAccess = pgTable(
  "role_module_access",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    roleId: uuid("role_id").notNull().references(() => roles.id, { onDelete: "cascade" }),
    moduleId: uuid("module_id").notNull().references(() => moduleAccess.id, { onDelete: "cascade" }),
    canView: boolean("can_view").notNull().default(false),
    canCreate: boolean("can_create").notNull().default(false),
    canUpdate: boolean("can_update").notNull().default(false),
    canDelete: boolean("can_delete").notNull().default(false),
    canApprove: boolean("can_approve").notNull().default(false),
    canExport: boolean("can_export").notNull().default(false),
    scope: text("scope").notNull().default("own"),
    ...timestamps
  },
  (table) => ({
    roleModuleUnique: uniqueIndex("role_module_access_role_module_unique").on(table.roleId, table.moduleId),
    roleIdx: index("role_module_access_role_idx").on(table.roleId),
    moduleIdx: index("role_module_access_module_idx").on(table.moduleId)
  })
);

export const userPermissionOverrides = pgTable(
  "user_permission_overrides",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    staffUserId: uuid("staff_user_id").notNull(),
    moduleKey: text("module_key").notNull(),
    action: text("action").notNull(),
    allowed: boolean("allowed").notNull(),
    reason: text("reason"),
    expiresAt: timestamp("expires_at", { withTimezone: true }),
    createdByUserId: uuid("created_by_user_id"),
    ...timestamps
  },
  (table) => ({
    staffModuleActionUnique: uniqueIndex("user_permission_overrides_staff_module_action_unique").on(
      table.staffUserId,
      table.moduleKey,
      table.action
    ),
    staffIdx: index("user_permission_overrides_staff_idx").on(table.staffUserId),
    moduleActionIdx: index("user_permission_overrides_module_action_idx").on(table.moduleKey, table.action)
  })
);

export const rolesRelations = relations(roles, ({ many }) => ({
  rolePermissions: many(rolePermissions),
  userRoles: many(userRoles),
  moduleAccess: many(roleModuleAccess)
}));

export const permissionsRelations = relations(permissions, ({ many }) => ({
  rolePermissions: many(rolePermissions)
}));

export const rolePermissionsRelations = relations(rolePermissions, ({ one }) => ({
  role: one(roles, { fields: [rolePermissions.roleId], references: [roles.id] }),
  permission: one(permissions, { fields: [rolePermissions.permissionId], references: [permissions.id] })
}));

export const userRolesRelations = relations(userRoles, ({ one }) => ({
  role: one(roles, { fields: [userRoles.roleId], references: [roles.id] })
}));

export const moduleAccessRelations = relations(moduleAccess, ({ many }) => ({
  roleAccess: many(roleModuleAccess)
}));

export const roleModuleAccessRelations = relations(roleModuleAccess, ({ one }) => ({
  role: one(roles, { fields: [roleModuleAccess.roleId], references: [roles.id] }),
  module: one(moduleAccess, { fields: [roleModuleAccess.moduleId], references: [moduleAccess.id] })
}));
