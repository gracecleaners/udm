import { api, extractApiError } from "@/lib/api";

/**
 * What the API says an account may reach, named in `accounts/permissions.py`.
 *
 * The console builds its own navigation from this list rather than a second
 * copy of the rules, so a control a page renders is a control the routes
 * accept.
 */
export type ConsoleCapability =
  | "curation"
  | "directory"
  | "moderation"
  | "translations"
  | "accounts";

/** Each capability named the way a page should say it out loud. */
export const CAPABILITY_LABEL: Record<ConsoleCapability, string> = {
  curation: "content",
  directory: "campus directory",
  moderation: "prayer queue",
  translations: "Bible editions",
  accounts: "staff accounts",
};

/** The list as one phrase, so a table cell and a profile page say it alike. */
export function capabilitiesText(capabilities: ConsoleCapability[] | undefined): string {
  return capabilities?.length
    ? capabilities.map((capability) => CAPABILITY_LABEL[capability]).join(", ")
    : "None";
}

export interface ConsoleIdentity {
  id: string;
  email: string;
  display_name: string;
  is_staff: boolean;
  is_superuser: boolean;
  /** Absent on an API that predates the capability list. */
  capabilities?: ConsoleCapability[];
}

interface SignInResponse extends ConsoleIdentity {
  access: string;
}

/**
 * Signs in to the ministry console.
 *
 * The API answers with the access token and the identity summary in the body,
 * and sets the refresh cookie itself, so there is nothing to hand back before
 * the browser can be re-admitted after a reload.
 */
export async function signIn(email: string, password: string): Promise<{ access: string; identity: ConsoleIdentity }> {
  try {
    const { data } = await api.post<SignInResponse>("/auth/admin/token/", { email, password }, {
      withCredentials: true,
    });
    const { access, ...identity } = data;
    return { access, identity };
  } catch (error) {
    throw new Error(extractApiError(error, "We could not sign you in."));
  }
}

export async function fetchIdentity(): Promise<ConsoleIdentity> {
  try {
    const { data } = await api.get<ConsoleIdentity>("/auth/admin/me/");
    return data;
  } catch (error) {
    throw new Error(extractApiError(error, "This account is not recognised as ministry staff."));
  }
}
