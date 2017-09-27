# encoding: utf-8

#  Copyright (c) 2017, Jungwacht Blauring Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

class Person::Filter::Role < Person::Filter::Base

  self.permitted_args = [:role_type_ids, :role_types, :kind, :start_at, :finish_at]

  def initialize(attr, args)
    super
    initialize_role_types
  end

  def apply(scope)
    scope.where(roles: { type: args[:role_types] }).where(duration_conditions)
  end

  def blank?
    args[:role_type_ids].blank?
  end

  def to_hash
    merge_duration_args(role_types: args[:role_types])
  end

  def to_params
    merge_duration_args(role_type_ids: args[:role_type_ids].join(ID_URL_SEPARATOR))
  end

  def with_deleted_roles?
    %w(active deleted).include?(args[:kind])
  end

  private

  def merge_duration_args(hash)
    hash.merge(args.slice(:kind, :start_at, :finish_at))
  end

  def initialize_role_types
    classes = role_classes
    args[:role_type_ids] = classes.map(&:id)
    args[:role_types] = classes.map(&:sti_name)
  end

  def role_classes
    if args[:role_types].present?
      role_classes_from_types
    else
      Role.types_by_ids(id_list(:role_type_ids))
    end
  end

  def role_classes_from_types
    map = Role.all_types.each_with_object({}) { |r, h| h[r.sti_name] = r }
    args[:role_types].map { |t| map[t] }.compact
  end

  def duration_conditions
    case args[:kind]
    when 'created' then { roles: { created_at: range }  }
    when 'deleted' then { roles: { deleted_at: range }  }
    when 'active' then
      ['roles.created_at <= :max OR ' \
       '(roles.deleted_at >= :min AND roles.deleted_at <= :max)',
       min: range.min, max: range.max]
    end
  end

  def range
    start_at = args[:start_at].presence || Role.minimum(:created_at).to_date.to_s
    finish_at = args[:finish_at].presence || Role.maximum(:updated_at).to_date.to_s
    Date.parse(start_at).beginning_of_day..Date.parse(finish_at).end_of_day
  end
end
