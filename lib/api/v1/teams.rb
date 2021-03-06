# frozen_string_literal: true

module API
  module V1
    class Teams < Grape::API
      version "v1", using: :path

      resource :teams do
        before do
          authorization!(force_admin: false)
        end

        desc "Returns list of teams",
             tags:     ["teams"],
             detail:   "This will expose all teams that the user is member of or has access to.
                        That mean if the user is an admin, this will return all the teams created by
                        all the users. If you want to check if the user is a member of a team, check
                        the role attribute.",
             is_array: true,
             entity:   API::Entities::Teams,
             failure:  [
               [401, "Authentication fails"],
               [403, "Authorization fails"]
             ]

        get do
          present policy_scope(Team), with: API::Entities::Teams, type: current_type
        end

        desc "Create a team",
             entity:   API::Entities::Teams,
             consumes: ["application/x-www-form-urlencoded", "application/json"],
             failure:  [
               [400, "Bad request", API::Entities::ApiErrors],
               [401, "Authentication fails"],
               [403, "Authorization fails"],
               [422, "Unprocessable Entity", API::Entities::FullApiErrors]
             ]

        params do
          requires :name, type: String, documentation: { desc: "Team name" }
          optional :description, type: String, documentation: { desc: "Team description" }
          optional :owner_id, type: Integer, documentation: { desc: "Team owner" }
        end

        post do
          authorize Team, :create?

          team = ::Teams::CreateService.new(current_user, permitted_params).execute

          if team.valid?
            present team,
                    with:         API::Entities::Teams,
                    current_user: current_user,
                    type:         current_type
          else
            unprocessable_entity!(team.errors)
          end
        end

        route_param :id, type: String, requirements: { id: /.*/ } do
          resource :namespaces do
            desc "Returns the list of namespaces for the given team",
                 params:   API::Entities::Teams.documentation.slice(:id),
                 is_array: true,
                 entity:   API::Entities::Namespaces,
                 failure:  [
                   [401, "Authentication fails"],
                   [403, "Authorization fails"],
                   [404, "Not found"]
                 ]

            get do
              team = Team.find params[:id]
              authorize team, :show?
              present team.namespaces, with: API::Entities::Namespaces, type: current_type
            end
          end

          resource :members do
            desc "Returns the list of team members",
                 params:   API::Entities::Teams.documentation.slice(:id),
                 is_array: true,
                 entity:   API::Entities::Users,
                 failure:  [
                   [401, "Authentication fails"],
                   [403, "Authorization fails"],
                   [404, "Not found"]
                 ]

            get do
              team = Team.find params[:id]
              authorize team, :member?
              present team.users, with: API::Entities::Users
            end
          end

          desc "Show teams by id",
               entity:  API::Entities::Teams,
               failure: [
                 [401, "Authentication fails"],
                 [403, "Authorization fails"],
                 [404, "Not found"]
               ]

          params do
            requires :id, type: String, documentation: { desc: "Team ID" }
          end

          get do
            team = Team.find(params[:id])
            authorize team, :show?
            present team, with: API::Entities::Teams, type: current_type
          end
        end
      end
    end
  end
end
