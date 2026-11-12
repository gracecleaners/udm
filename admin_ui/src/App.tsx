import { lazy, Suspense } from "react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Route, Routes } from "react-router-dom";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { Toaster } from "@/components/ui/toaster";
import { TooltipProvider } from "@/components/ui/tooltip";
import { AuthProvider } from "@/contexts/AuthContext";
import { ProtectedRoute } from "@/components/ProtectedRoute";
import { AppShell } from "@/components/layout/AppShell";

const Login = lazy(() => import("./pages/Login"));
const Overview = lazy(() => import("./pages/Overview"));
const Devotions = lazy(() => import("./pages/Devotions"));
const Series = lazy(() => import("./pages/Series"));
const Articles = lazy(() => import("./pages/Articles"));
const ResourceGuides = lazy(() => import("./pages/ResourceGuides"));
const ResourceSteps = lazy(() => import("./pages/ResourceSteps"));
const ReadingPlans = lazy(() => import("./pages/ReadingPlans"));
const Translations = lazy(() => import("./pages/Translations"));
const MediaShelves = lazy(() => import("./pages/MediaCollections"));
const MediaRecordings = lazy(() => import("./pages/MediaItems"));
const MemoryVerses = lazy(() => import("./pages/MemoryVerses"));
const Universities = lazy(() => import("./pages/Universities"));
const Campuses = lazy(() => import("./pages/Campuses"));
const Fellowships = lazy(() => import("./pages/Fellowships"));
const Groups = lazy(() => import("./pages/Groups"));
const Events = lazy(() => import("./pages/Events"));
const Students = lazy(() => import("./pages/Students"));
const PrayerQueue = lazy(() => import("./pages/PrayerQueue"));
const Account = lazy(() => import("./pages/Account"));
const NotFound = lazy(() => import("./pages/NotFound"));

const queryClient = new QueryClient({
  defaultOptions: { queries: { retry: 1, refetchOnWindowFocus: false } },
});

const App = () => (
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <Toaster />
      <Sonner />
      <BrowserRouter>
        <AuthProvider>
          <Suspense fallback={<div className="route-loading" role="status">Loading workspace…</div>}>
            <Routes>
              <Route path="/login" element={<Login />} />
              <Route
                element={
                  <ProtectedRoute>
                    <AppShell />
                  </ProtectedRoute>
                }
              >
                <Route path="/" element={<Overview />} />
                <Route path="/devotions" element={<Devotions />} />
                <Route path="/series" element={<Series />} />
                <Route path="/articles" element={<Articles />} />
                <Route path="/resource-guides" element={<ResourceGuides />} />
                <Route path="/resource-steps" element={<ResourceSteps />} />
                <Route path="/plans" element={<ReadingPlans />} />
                <Route path="/translations" element={<Translations />} />
                <Route path="/media-shelves" element={<MediaShelves />} />
                <Route path="/media-recordings" element={<MediaRecordings />} />
                <Route path="/memory-verses" element={<MemoryVerses />} />
                <Route path="/universities" element={<Universities />} />
                <Route path="/campuses" element={<Campuses />} />
                <Route path="/fellowships" element={<Fellowships />} />
                <Route path="/groups" element={<Groups />} />
                <Route path="/events" element={<Events />} />
                <Route path="/students" element={<Students />} />
                <Route path="/prayers" element={<PrayerQueue />} />
                <Route path="/account" element={<Account />} />
              </Route>
              <Route path="*" element={<NotFound />} />
            </Routes>
          </Suspense>
        </AuthProvider>
      </BrowserRouter>
    </TooltipProvider>
  </QueryClientProvider>
);

export default App;
