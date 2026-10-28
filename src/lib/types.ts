export type Role = "superadmin" | "org_admin" | "editor";

export type Profile = {
  id: string;
  organization_id: string | null;
  role: Role;
  email: string | null;
};

export type Organization = {
  id: string;
  name: string;
  package_id: string | null;
  max_screens: number;
  is_active: boolean;
};

export type Product = {
  id: string;
  organization_id: string;
  name: string;
  price: number;
  campaign_price: number | null;
  image_url: string | null;
  category: string | null;
  is_active: boolean;
  sort_order: number;
};

// What a screen shows: chosen template, optional theme, and the template's fields.
export type ScreenContent = {
  template?: string;
  theme?: string | null;
  fields?: Record<string, unknown>;
};

export type Screen = {
  id: string;
  organization_id: string;
  location_id: string | null;
  name: string;
  orientation: "landscape" | "portrait";
  draft_content: ScreenContent;
  published_content: ScreenContent | null;
  layout: { x: number; y: number };
  sort_order: number;
  last_seen_at: string | null;
  published_at: string | null;
};
