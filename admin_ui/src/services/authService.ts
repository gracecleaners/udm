import { api, extractApiError } from "@/lib/api";

export interface ConsoleIdentity {
  id: string;
  email: string;
  display_name: string;
  is_staff: boolean;
  is_superuser: boolean;
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
